#!/bin/bash
#### SCRIPT USED TO DEPLOY CAP on AKS & more
#### Jean Marc LAMBERT, SUSE EMEA Consulting
#### 07 AUG 2019
#### FUNCTIONS used by the script

init-cap-deployment(){
        #Check if AKSDEPLOYID envvar exist
        if [[ -z "${AKSDEPLOYID}" ]]; then
          echo "This script expects AKSDEPLOYID envvar to be provided"; exit
        else
          [ -f  "$AKSDEPLOYID/.envvar.sh" ]; source $AKSDEPLOYID/.envvar.sh;
        fi
	if [ ! "$REGION" == "jmlzone" ]; then 
        	export SUBSCRIPTION_ID=$(az account show | jq -r '.id')
        	echo "export SUBSCRIPTION_ID=$SUBSCRIPTION_ID" >> $AKSDEPLOYID/.envvar.sh
        fi
	export KUBECONFIG="$AKSDEPLOYID/kubeconfig"
        echo "export KUBECONFIG=$KUBECONFIG" >>$AKSDEPLOYID/.envvar.sh
	echo ">>>>>> Welcome to the CAPandMORE deployment tool <<<<<<<"
	kubectl get nodes
	echo " Current installed version $CAP_VERSION"
}
get-chart-versions(){
                case $1 in
                        "1.3.0")
                           export UAA_HELM_VERSION=" --version 2.14.5 "
                           export SCF_HELM_VERSION=" --version 2.14.5 "
                           export CONSOLE_HELM_VERSION=" --version 2.2.0 "
                           export NEXT_UPGRADE_PATH="1.3.1"
                           ;;
                        "1.3.1")
                           export UAA_HELM_VERSION=" --version 2.15.2 "
                           export SCF_HELM_VERSION=" --version 2.15.2 "
                           export CONSOLE_HELM_VERSION=" --version 2.3.0 "
                           export NEXT_UPGRADE_PATH="1.4.0"
                           ;;
                        "1.4.0")
                           export UAA_HELM_VERSION=" --version 2.16.4 "
                           export SCF_HELM_VERSION=" --version 2.16.4 "
                           export CONSOLE_HELM_VERSION=" --version 2.4.0 "
                           export NEXT_UPGRADE_PATH="1.4.1"
                           ;;
                   	"1.4.1")
                           export UAA_HELM_VERSION=" --version 2.17.1 "
                           export SCF_HELM_VERSION=" --version 2.17.1 "
                           export CONSOLE_HELM_VERSION=" --version 2.4.0 "
			   export NEXT_UPGRADE_PATH="1.4.2"
                           ;;
	 	        *)echo "Undefined version";;
                esac
		echo "export CAP_VERSION=\"$1\"" >> $AKSDEPLOYID/.envvar.sh;
        echo "export UAA_HELM_VERSION=\"$UAA_HELM_VERSION\"" >> $AKSDEPLOYID/.envvar.sh;
        echo "export SCF_HELM_VERSION=\"$SCF_HELM_VERSION\"" >> $AKSDEPLOYID/.envvar.sh;
        echo "export CONSOLE_HELM_VERSION=\"$CONSOLE_HELM_VERSION\"" >> $AKSDEPLOYID/.envvar.sh;
        echo "export NEXT_UPGRADE_PATH=\"$NEXT_UPGRADE_PATH\"" >> $AKSDEPLOYID/.envvar.sh;
 echo ">>> Installing CAP version $CAP_VERSION <<<"

}
select_cap-version(){
        if [[ -z "${CAP_VERSION}" ]]; then
        PS3='Please enter your choice: '
        set -e
        capversions=("1.3.0" "1.3.1" "1.4.0" "1.4.1")
        select ver in "${capversions[@]}"
        do
	   get-chart-versions $ver
           break
        done
        fi
}

review-cap-config-file(){
        vim $AKSDEPLOYID/scf-config-values.yaml
}
watch-pods-of-ns(){
        watch kubectl get pods -n "$1"
}

wait-for-pods-ready-of-ns(){
        echo "Wait for $1 pods to be ready"
        PODSTATUS="1" ; NS=$1 ;
        while [ $PODSTATUS -ne "0" ]; do
          sleep 20 ;
          PODSTATUS=$(kubectl get pod -n $NS|awk 'BEGIN{cnt=0}!/Completed/{if(substr($2,1,1)<substr($2,3,1))cnt=cnt+1;}END{print cnt} ');
          echo "Til $PODSTATUS pods to wait for in $NS";
        done
}
install-helm(){
        kubectl apply -f $AKSDEPLOYID/helm-rbac-config.yaml
        watch kubectl get pod -n kube-system|grep tiller
        helm init --service-account=tiller
}
deploy-nfs-provionner-local(){
        helm install --name nfs-provisioner stable/nfs-client-provisioner -f $AKSDEPLOYID/nfs-client-provisioner-values.yaml --namespace=kube-system
}
deploy-cap-uaa(){
    helm install suse/uaa $UAA_HELM_VERSION --name susecf-uaa --namespace uaa --values $AKSDEPLOYID/scf-config-values.yaml
}

upgrade-cap-uaa(){
    helm upgrade susecf-uaa suse/uaa $UAA_HELM_VERSION --force --recreate-pods --values $AKSDEPLOYID/scf-config-values.yaml
}

deploy-cap-scf(){
        SECRET=$(kubectl get pods --namespace uaa -o jsonpath='{.items[?(.metadata.name=="uaa-0")].spec.containers[?(.name=="uaa")].env[?(.name=="INTERNAL_CA_CERT")].valueFrom.secretKeyRef.name}');
        CA_CERT="$(kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['internal-ca-cert']}" | base64 --decode -)";
        echo "CA_CERT=$CA_CERT";
        helm install suse/cf $SCF_HELM_VERSION --name susecf-scf --namespace scf --values $AKSDEPLOYID/scf-config-values.yaml --set "secrets.UAA_CA_CERT=${CA_CERT}"
}
upgrade-cap-scf(){
        # Options example "--force --grace-period=0"
        local OPTIONS=$1
        SECRET=$(kubectl get pods --namespace uaa -o jsonpath='{.items[?(.metadata.name=="uaa-0")].spec.containers[?(.name=="uaa")].env[?(.name=="INTERNAL_CA_CERT")].valueFrom.secretKeyRef.name}');
        CA_CERT="$(kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['internal-ca-cert']}" | base64 --decode -)";
        echo "CA_CERT=$CA_CERT";
        helm upgrade susecf-scf suse/cf $SCF_HELM_VERSION --namespace scf $OPTIONS  --values $AKSDEPLOYID/scf-config-values.yaml --set "secrets.UAA_CA_CERT=${CA_CERT}"
}
deploy-cap-stratos(){
	local OPTIONS=""
	if [ ! "$REGION" == "jmlzone" ];then
	    OPTIONS=" --set services.loadbalanced=true "
        fi
        helm install suse/console $CONSOLE_HELM_VERSION --name susecf-console --namespace stratos --values $AKSDEPLOYID/scf-config-values.yaml $OPTIONS  --set metrics.enabled=true
}
deploy-cap-metrics(){
	local OPTIONS=""
        if [ "$REGION" == "jmlzone" ];then
            OPTIONS=" --values $AKSDEPLOYID/stratos-metrics-values.yaml "
        fi

        helm install suse/metrics --name susecf-metrics --namespace=metrics --values $AKSDEPLOYID/scf-config-values.yaml $OPTIONS
}

deploy-azure-catalog(){
        helm repo add svc-cat https://svc-catalog-charts.storage.googleapis.com ;
        helm repo update;
        helm install svc-cat/catalog --name catalog --namespace catalog --set apiserver.storage.etcd.persistence.enabled=true \
        --set apiserver.healthcheck.enabled=false --set controllerManager.healthcheck.enabled=false --set apiserver.verbosity=2 \
        --set controllerManager.verbosity=2
}
create-azure-servicebroker(){
        export SUBSCRIPTION_ID=$(az account show | jq -r '.id')
        export REGION="$REGION"
        export SBRGNAME=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 8)-service-broker
        az group create --name ${SBRGNAME} --location ${REGION}
        echo SBRGNAME=${SBRGNAME}
        export SERVICE_PRINCIPAL_INFO="$(az ad sp create-for-rbac --name ${SBRGNAME})"
        echo "export SBRGNAME=$SBRGNAME" >>$AKSDEPLOYID/.envvar.sh
        echo "export REGION=$REGION" >>$AKSDEPLOYID/.envvar.sh
        echo "export SERVICE_PRINCIPAL_INFO='$SERVICE_PRINCIPAL_INFO'" >>$AKSDEPLOYID/.envvar.sh
}
delete-azure-servicebroker(){
	if [ ! "$REGION" == "jmlzone" ]; then
        	az group delete --name $1 
	fi
}
deploy-azure-osba(){
        helm repo add azure https://kubernetescharts.blob.core.windows.net/azure;
        helm repo update;
        TENANT_ID=$(echo ${SERVICE_PRINCIPAL_INFO} | jq -r '.tenant')
        CLIENT_ID=$(echo ${SERVICE_PRINCIPAL_INFO} | jq -r '.appId')
        CLIENT_SECRET=$(echo ${SERVICE_PRINCIPAL_INFO} | jq -r '.password')
        echo REGION=${REGION};
        echo SUBSCRIPTION_ID=${SUBSCRIPTION_ID} \; TENANT_ID=${TENANT_ID}\; CLIENT_ID=${CLIENT_ID}\; CLIENT_SECRET=${CLIENT_SECRET}
        helm install azure/open-service-broker-azure --name osba --namespace osba \
        --set azure.subscriptionId=${SUBSCRIPTION_ID} \
        --set azure.tenantId=${TENANT_ID} \
        --set azure.clientId=${CLIENT_ID} \
        --set azure.clientSecret=${CLIENT_SECRET} \
        --set azure.defaultLocation=${REGION} \
        --set redis.persistence.storageClass=default \
        --set basicAuth.username=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16) \
        --set basicAuth.password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16) \
        --set tls.enabled=false
}
deploy-minibroker(){
        helm install suse/minibroker --namespace minibroker --name minibroker --set "defaultNamespace=minibroker"
}
cf-create-minibroker-sb(){
 	cf create-service-broker minibroker user pass http://minibroker-minibroker.minibroker.svc.cluster.local
	cf enable-service-access redis
	cf enable-service-access mongodb
	cf enable-service-access mariadb
	cf enable-service-access postgresql
	cf enable-service-access mysql
	cf create-security-group redis_networking  $AKSDEPLOYID/redis.json
	cf create-security-group mongo_networking  $AKSDEPLOYID/mongo.json
	cf create-security-group mysql_networking  $AKSDEPLOYID/mysql.json
	cf bind-security-group redis_networking testorg scftest
	cf bind-security-group mongo_networking testorg scftest
	cf bind-security-group mysql_networking testorg scftest
}
cf-set-api(){
	if [[ -z "${CFEP}" ]]; then
	  CFEP=$(awk '/Public IP:/{print "https://api." $NF ".xip.io"}' $AKSDEPLOYID/deployment.log)
        fi
        echo "CF Endpoint : $CFEP"
        cf api --skip-ssl-validation $CFEP
        ADMINPSW=$(awk '/CLUSTER_ADMIN_PASSWORD:/{print $NF}' $AKSDEPLOYID/scf-config-values.yaml)
        cf login -u admin -p $ADMINPSW
}
cf-create-azure-sb(){
        cf create-service-broker azure${REGION} $(kubectl get deployment osba-open-service-broker-azure \
        --namespace osba -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name == "BASIC_AUTH_USERNAME")].value}') $(kubectl get secret --namespace osba osba-open-service-broker-azure -o jsonpath='{.data.basic-auth-password}' | base64 -d) http://osba-open-service-broker-azure.osba
        cf service-access -b azure${REGION} | awk '($2 ~ /basic/)||($1 ~ /mongo/) { system("cf enable-service-access " $1 " -p " $2 " -b " brok)}/^broker:/{brok=$2}'
}
cf-create-org-space(){
        cf create-org testorg;
        cf create-space scftest -o testorg;
        cf target -o "testorg" -s "scftest";
}
cf-create-service-mysql-ex1-az(){
        cf create-service azure-mysql-5-7 basic scf-rails-example-db -c "{ \"location\": \"${REGION}\", \"resourceGroup\": \"${SBRGNAME}\", \"firewallRules\": [{\"name\": \"AllowAll\", \"startIPAddress\":\"0.0.0.0\",\"endIPAddress\":\"255.255.255.255\"}]}";
}
cf-create-service-mysql-ex1-mb(){
	cf create-service mysql 5-7-14  scf-rails-example-db   -c '{"mysqlDatabase":"todos"}'
}
cf-create-service-mongodb-ex2-az(){
	cf create-service azure-cosmosdb-mongo-account account scf-mongo-db -c "{ \"location\": \"${REGION}\", \"resourceGroup\": \"${SBRGNAME}\"}"
}

cf-create-service-mongodb-ex2-mb(){
        cf create-service mongodb 4-0-8 scf-mongo-db 
}
cf-wait-service-created(){
                ## $1 Param : service Name expected
        echo "Wait for SCF 1st Service to be ready"
        PODSTATUS=$(cf service $1|awk "/^status:/{print \$NF}");
        while [ $PODSTATUS != "succeeded" ]; do
                sleep 20 ;
                PODSTATUS=$(cf service $1|awk "/^status:/{print \$NF}");
                echo "Status $PODSTATUS for db service";
        done
}
azure-disable-ssl-mysql(){
        az mysql server list --resource-group $SBRGNAME|jq '.[] |select(.sslEnforcement=="Enabled")' |awk '/name.*-/{print "az mysql server update --resource-group $SBRGNAME --name " substr($2,2,length($2)-3) " --ssl-enforcement Disabled"}'|sh
}
cf-deploy-rails-ex1(){
        echo "Clone the rails application to consume the mySQL db"
        if [ ! -d "$AKSDEPLOYID/rails-example" ]; then
        # Control will enter here if $DIRECTORY doesn't exist.
                git clone https://github.com/jmlambert78/rails-example $AKSDEPLOYID/rails-example
        fi
        cd $AKSDEPLOYID/rails-example
        echo "Push the application to SCF"
	cf push #-c 'rake db:seed' -i 1
        #cf push
        #cf push -c 'rake db:seed' -i 1
        echo "Populate the DB with sample data"
        cf ssh scf-rails-example -c "export PATH=/home/vcap/deps/0/bin:/usr/local/bin:/usr/bin:/bin && \
                export BUNDLE_PATH=/home/vcap/deps/0/vendor_bundle/ruby/2.5.0 && \
                export BUNDLE_GEMFILE=/home/vcap/app/Gemfile && cd app && bundle exec rake db:seed"
        cd ../..
        cf apps
        cf services
        echo "Test the app"
        cf apps|awk '/scf-rails-example/{print "curl " $NF }'|sh
}
cf-deploy-nodejs-ex1(){
        echo "Clone the nodejs application to consume mongodb db"

        if [ ! -d "$AKSDEPLOYID/nodejs-example" ]; then
        	# Control will enter here if $DIRECTORY doesn't exist.
        	git clone https://github.com/jmlambert78/node-backbone-mongo $AKSDEPLOYID/nodejs-example
	fi
        cd $AKSDEPLOYID/nodejs-example
        echo "Push the application to SCF"
        cf push 
	#cf bs node-backbone-mongo scf-mongo-db
        #cf restage node-backbone-mongo -v
        cd ../..
        cf apps
        cf services
        echo "Test the app"
        cf apps|awk '/node-backbone-mongo/{print "curl " $NF }'|sh
}
helm-delete-and-ns(){
        helm delete --purge $1
		kubectl delete ns $2
}


######## START OF EXEC

init-cap-deployment
select_cap-version

PS3='Please enter your choice: '
set -e
options=("Quit" "Review scfConfig" "Deploy UAA" "Pods UAA" \
 "Deploy SCF" "Pods SCF" "Deploy AZ CATALOG" "Pods AZ CATALOG" \
"Create AZ SB" "Deploy AZ OSBA" "Pods AZ OSBA" "Deploy Minibroker SB" "CF API set" \
"CF Add AZ SB" "CF CreateOrgSpace" "CF 1st mysql Service" \
"CF Wait for 1st Service Created" "AZ Disable SSL Mysql DBs" "Deploy 1st Rails Appl" \
"Deploy Stratos SCF Console" "Pods Stratos" "Deploy Metrics" "Pods Metrics" \
"CF 1st mongoDB Service" "CF Wait for mongoDB Service" "Deploy 2nd App Nodejs" \
"All Azure" "All localk8S" "DELETE CAP"  "Upgrade Version")
select opt in "${options[@]}"
do
    case $opt in
        "Quit")
            break
            ;;
        "Review scfConfig")
            review-cap-config-file
            ;;
	"Upgrade Version")
	    oldPS3="$PS3"
	    
	    PS3="Next Proposed version is $NEXT_UPGRADE_PATH Agree?"
	    select approved in Yes No
	    do
    		case $approved in
		"Yes")
			get-chart-versions "$NEXT_UPGRADE_PATH"	
			upgrade-cap-uaa
			wait-for-pods-ready-of-ns uaa

			upgrade-cap-scf
 		     	wait-for-pods-ready-of-ns scf

			break 
		;;
		*)break;;
		esac
	    done
	    PS3="$oldPS3"
	    ;; 
       "Deploy UAA")
            deploy-cap-uaa
            ;;
        "Pods UAA")
            watch-pods-of-ns uaa
            ;;
        "Deploy SCF")
            deploy-cap-scf
            ;;
        "Pods SCF")
            watch-pods-of-ns scf
            ;;
        "Deploy AZ CATALOG")
            deploy-azure-catalog
            ;;
       "Pods AZ CATALOG")
            watch-pods-of-ns catalog
            ;;
       "Create AZ SB")
            create-azure-servicebroker
            ;;
       "Deploy AZ OSBA")
            deploy-azure-osba
            ;;
       "Pods AZ OSBA")
            watch-pods-of-ns osba
            ;;
       "CF API set")
            cf-set-api
            ;;
        "CF Add AZ SB")
            cf-create-azure-sb
            ;;
       "Deploy Minibroker SB")
            deploy-minibroker
	    wait-for-pods-ready-of-ns minibroker 
	    cf-create-minibroker-sb
            ;;
         "CF CreateOrgSpace")
            cf-create-org-space
            ;;
        "CF 1st mysql Service")
        if [ ! "$REGION" == "jmlzone" ]; then
            cf-create-service-mysql-ex1-az
        else
            cf-create-service-mysql-ex1-mb
	fi
            ;;
        "CF Wait for 1st Service Created")
            cf-wait-service-created scf-rails-example-db
            ;;
       "AZ Disable SSL Mysql DBs")
            azure-disable-ssl-mysql
            ;;
        "Deploy 1st Rails Appl")
            cf-deploy-rails-ex1
            ;;
        "Deploy Stratos SCF Console")
            deploy-cap-stratos
            ;;
        "Pods Stratos")
            watch-pods-of-ns stratos
            ;;
        "Deploy Metrics")
            deploy-cap-metrics
            ;;
        "Pods Metrics")
            watch-pods-of-ns metrics
            ;;
        "CF 1st mongoDB Service")
	 if [ ! "$REGION" == "jmlzone" ]; then
            cf-create-service-mongodb-ex2-az
        else
            cf-create-service-mongodb-ex2-mb
        fi
            ;;
        "CF Wait for mongoDB Service")
            cf-wait-service-created scf-mongo-db ;
            ;;
        "Deploy 2nd App Nodejs")
            cf-deploy-nodejs-ex1
            ;;
        "All Azure")
            deploy-cap-uaa
            wait-for-pods-ready-of-ns uaa
                        deploy-cap-scf
            wait-for-pods-ready-of-ns scf
            deploy-azure-catalog
            wait-for-pods-ready-of-ns catalog
                        create-azure-servicebroker
                        deploy-azure-osba
                        wait-for-pods-ready-of-ns osba
                        cf-set-api
                        cf-create-azure-sb
                        cf-create-org-space
                        cf-create-service-mysql-ex1-az
                        cf-wait-service-created scf-rails-example-db
                        azure-disable-ssl-mysql
                        cf-deploy-rails-ex1
                        deploy-cap-stratos
                        wait-for-pods-ready-of-ns stratos
                        deploy-cap-metrics
                        wait-for-pods-ready-of-ns metrics
                        cf-create-service-mongodb-ex2-az
                        cf-wait-service-created scf-mongo-db 
                        cf-deploy-nodejs-ex1
            ;;
	"All localk8S")
            deploy-cap-uaa
            wait-for-pods-ready-of-ns uaa
            deploy-cap-scf
            wait-for-pods-ready-of-ns scf
            cf-set-api
            cf-create-org-space
	    deploy-minibroker
	    wait-for-pods-ready-of-ns minibroker
	    cf-create-minibroker-sb
                        cf-create-service-mysql-ex1-mb
                        cf-wait-service-created scf-rails-example-db 
                        cf-deploy-rails-ex1
                        deploy-cap-stratos
                        wait-for-pods-ready-of-ns stratos
                        deploy-cap-metrics
                        wait-for-pods-ready-of-ns metrics
                        cf-create-service-mongodb-ex2-mb
                        cf-wait-service-created scf-mongo-db
                        cf-deploy-nodejs-ex1

		;;
        "DELETE CAP")
                hlist=$(helm list -q)

				if [[ $hlist == *"susecf-scf"* ]]; then
				helm-delete-and-ns susecf-uaa uaa 
				fi
				if [[ $hlist == *"susecf-scf"* ]]; then
				helm-delete-and-ns susecf-scf scf
				fi
				if [[ $hlist == *"susecf-console"* ]]; then
				helm-delete-and-ns susecf-console stratos
				fi
				if [[ $hlist == *"susecf-metrics"* ]]; then
				helm-delete-and-ns susecf-metrics metrics
				fi
				if [[ $hlist == *"minibroker"* ]]; then
				helm-delete-and-ns minibroker minibroker
				fi
				if [[ $hlist == *"osba"* ]]; then
				helm-delete-and-ns osba osba
				fi
				if [[ $hlist == *"catalog"* ]]; then
				helm-delete-and-ns catalog catalog
				fi
				delete-azure-servicebroker $SBRGNAME
            ;;
        *) echo "invalid option $REPLY";;
    esac
done


