#!/bin/bash
#### SCRIPT USED TO DEPLOY CAP on AKS & more
#### Jean Marc LAMBERT, SUSE EMEA Consulting
#### 07 AUG 2019
#### FUNCTIONS used by the script
set -x
save-envvar(){
	echo "$1" >> $AKSDEPLOYID/.envvar.sh
}
log-action(){
local ts=`date +'%Y-%m-%d_%Hh%M'`
	echo "$ts: $1" >> $AKSDEPLOYID/history_actions.log
}
log-environment(){
	log-action "vvvvvv Current environment : "
	log-action "PWD: $(pwd)"$'\n'">>> kubectl get nodes <<<"$'\n'"$(kubectl get nodes)"$'\n'\
">>> helm list <<<"$'\n'"$(helm list)"$'\n'">>> kubectl get ns <<<"$'\n'"$(kubectl get ns)"
	log-action "^^^^^^ Current environment"
}
log-environment-helm(){
	log-action "vvvvvv Current environment : "
	log-action "PWD: $(pwd)"$'\n'">>> helm list <<<"$'\n'"$(helm list)"$'\n'
	log-action "^^^^^^ Current environment"
}


init-cap-deployment(){
	#Check if AKSDEPLOYID envvar exist
	if [[ -z "${AKSDEPLOYID}" ]]; then
	  echo "This script expects AKSDEPLOYID envvar to be provided"; exit
	else
	  [ -f  "$AKSDEPLOYID/.envvar.sh" ]; source $AKSDEPLOYID/.envvar.sh;
	fi
	if [ ! "$REGION" == "yourzone" ]; then
			export SUBSCRIPTION_ID=$(az account show | jq -r '.id')
			save-envvar "export SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
	fi
	export KUBECONFIG="$AKSDEPLOYID/kubeconfig"
	save-envvar "export KUBECONFIG=$KUBECONFIG"
	echo ">>>>>> Welcome to the CAPnMORE deployment tool <<<<<<<"
	kubectl get nodes
	echo " Current selected version : $CAP_VERSION"
	log-action "Launch CAPnMore : Current selected version $CAP_VERSION"
	log-environment
}
get-chart-versions(){
	case $1 in
		"1.3.0")
		   export UAA_HELM_VERSION=" suse/uaa --version 2.14.5 "
		   export SCF_HELM_VERSION=" suse/cf --version 2.14.5 "
		   export CONSOLE_HELM_VERSION=" --version 2.2.0 "
		   export METRICS_HELM_VERSION=" --version 1.0.0 "
		   export NEXT_UPGRADE_PATH="1.3.1"
		   ;;
		"1.3.1")
		   export UAA_HELM_VERSION=" suse/uaa --version 2.15.2 "
		   export SCF_HELM_VERSION=" suse/cf --version 2.15.2 "
		   export CONSOLE_HELM_VERSION=" --version 2.3.0 "
		   export METRICS_HELM_VERSION=" --version 1.0.0 "
		   export NEXT_UPGRADE_PATH="1.4.0"
		   ;;
		"1.4.0")
		   export UAA_HELM_VERSION=" suse/uaa --version 2.16.4 "
		   export SCF_HELM_VERSION=" suse/cf --version 2.16.4 "
		   export CONSOLE_HELM_VERSION=" --version 2.5.3 "
		   export METRICS_HELM_VERSION=" --version 1.0.0 "
		   export NEXT_UPGRADE_PATH="1.4.1"
		   ;;
		"1.4.1")
		   export UAA_HELM_VERSION=" suse/uaa --version 2.17.1 "
		   export SCF_HELM_VERSION=" suse/cf --version 2.17.1 "
		   export CONSOLE_HELM_VERSION=" --version 2.5.3 "
		   export METRICS_HELM_VERSION=" --version 1.1.0 "
		   export NEXT_UPGRADE_PATH="1.5.0"
		   ;;
	   "1.5.0")
		   export UAA_HELM_VERSION=" suse/uaa --version 2.18.0 "
		   export SCF_HELM_VERSION=" suse/cf --version 2.18.0 "
		   export CONSOLE_HELM_VERSION=" --version 2.6.0 "
		   export METRICS_HELM_VERSION=" --version 1.1.0 "
		   export NEXT_UPGRADE_PATH="1.5.1RC1"
		   ;;
           "1.5.1RC1")
                   export UAA_HELM_VERSION="NO"
                   export SCF_HELM_VERSION=" /home/jmlambert/cap151RC1/helm/cf "
                   export CONSOLE_HELM_VERSION=" --version 2.6.0 "
                   export METRICS_HELM_VERSION=" --version 1.1.0 "
                   export NEXT_UPGRADE_PATH="1.5.2"
                   ;;


		*)echo "Undefined version";;
	esac
	export CAP_VERSION="$1"
	save-envvar "export CAP_VERSION=\"$CAP_VERSION\"" ;
	save-envvar "export UAA_HELM_VERSION=\"$UAA_HELM_VERSION\"";
	save-envvar "export SCF_HELM_VERSION=\"$SCF_HELM_VERSION\"";
	save-envvar "export CONSOLE_HELM_VERSION=\"$CONSOLE_HELM_VERSION\"";
	save-envvar "export METRICS_HELM_VERSION=\"$METRICS_HELM_VERSION\"";
	save-envvar "export NEXT_UPGRADE_PATH=\"$NEXT_UPGRADE_PATH\"";
echo ">>> Installing CAP version $CAP_VERSION <<<"
log-action "CAP version $CAP_VERSION defined"
}
select_cap-version(){
	if [[ -z "${CAP_VERSION}" ]]; then
	PS3='Please enter your choice: '
	capversions=("1.3.0" "1.3.1" "1.4.0" "1.4.1" "1.5.0" "1.5.1RC1")
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
review-metrics-config-file(){
	vim $AKSDEPLOYID/stratos-metrics-values.yaml
}


watch-pods-of-ns(){
	watch kubectl get pods -n "$1"
	log-action "Watch pods for $1"
}

wait-for-pods-ready-of-ns(){
log-action "Wait for pods readiness for $1"
	echo "Wait for $1 pods to be ready"
	PODSTATUS="1" ; NS=$1 ;
	while [ $PODSTATUS -ne "0" ]; do
		sleep 20 ;
		PODSTATUS=$(kubectl get pod -n $NS|awk 'BEGIN{cnt=0}!/Completed/{if(substr($2,1,1)<substr($2,3,1))cnt=cnt+1;}END{print cnt} ');
		echo "Til $PODSTATUS pods to wait for in $NS";
	done
log-action "All pods ready for $1"

}
install-helm(){
	kubectl apply -f $AKSDEPLOYID/helm-rbac-config.yaml
	helm init --service-account=tiller
	wait-for-pods-ready-of-ns kube-system
}
deploy-nfs-provisioner-local(){
	helm install --name nfs-provisioner stable/nfs-client-provisioner -f $AKSDEPLOYID/nfs-client-provisioner-values.yaml --namespace=kube-system
	log-environment-helm
}
deploy-ingress-controller(){
        helm install --name nginx-ingress suse/nginx-ingress -f $AKSDEPLOYID/nginx-ingress-values.yaml --namespace=ingress
        log-environment-helm
	wait-for-pods-ready-of-ns ingress
}
deploy-cap-uaa(){
    if [ ! "$UAA_HELM_VERSION" == "NO" ];then
      log-action "Installing UAA  $UAA_HELM_VERSION"
      helm install $UAA_HELM_VERSION --name susecf-uaa --namespace uaa --values $AKSDEPLOYID/scf-config-values.yaml
      log-environment-helm
    fi
}

upgrade-cap-uaa(){
    log-action "Upgrading UAA  $UAA_HELM_VERSION"
    helm upgrade susecf-uaa $UAA_HELM_VERSION --force --recreate-pods --values $AKSDEPLOYID/scf-config-values.yaml
    log-environment-helm
}

deploy-cap-scf(){
	log-action "Installing SCF  $SCF_HELM_VERSION"
 
	SECRET=$(kubectl get pods --namespace uaa -o jsonpath='{.items[?(.metadata.name=="uaa-0")].spec.containers[?(.name=="uaa")].env[?(.name=="INTERNAL_CA_CERT")].valueFrom.secretKeyRef.name}');
	CA_CERT="$(kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['internal-ca-cert']}" | base64 --decode -)";
	echo "CA_CERT=$CA_CERT";
	helm install $SCF_HELM_VERSION --name susecf-scf --namespace scf --values $AKSDEPLOYID/scf-config-values.yaml --values $AKSDEPLOYID/scf-encryption-key.yaml --set "secrets.UAA_CA_CERT=${CA_CERT}"
	log-environment-helm
}
deploy-cap-scf-rc1(){
        log-action "Installing SCF  $SCF_HELM_VERSION 1.5.1 RC1 special"
        helm install $SCF_HELM_VERSION  --name susecf-scf --namespace scf --values $AKSDEPLOYID/scf-config-values.yaml --set kube.organization="cap-staging"
        log-environment-helm
}


upgrade-cap-scf(){
	log-action "Upgrading SCF  $SCF_HELM_VERSION"
	# Options example "--force --grace-period=0"
	local OPTIONS=$1
	SECRET=$(kubectl get pods --namespace uaa -o jsonpath='{.items[?(.metadata.name=="uaa-0")].spec.containers[?(.name=="uaa")].env[?(.name=="INTERNAL_CA_CERT")].valueFrom.secretKeyRef.name}');
	CA_CERT="$(kubectl get secret $SECRET --namespace uaa -o jsonpath="{.data['internal-ca-cert']}" | base64 --decode -)";
	echo "CA_CERT=$CA_CERT";
	helm upgrade susecf-scf suse/cf $SCF_HELM_VERSION --namespace scf $OPTIONS  --values $AKSDEPLOYID/scf-config-values.yaml --values $AKSDEPLOYID/scf-encryption-key.yaml --set "secrets.UAA_CA_CERT=${CA_CERT}"
	log-environment-helm
}
deploy-cap-stratos(){
	log-action "Installing STRATOS  $CONSOLE_HELM_VERSION"
	local OPTIONS=""
	if [ ! "$REGION" == "yourzone" ];then
		OPTIONS=" --set services.loadbalanced=true "
	fi
	local TECH_PREVIEW_OPTION=""
	if [ "$CONSOLE_HELM_VERSION" == " --version 2.5.2 " ];then
		TECH_PREVIEW_OPTION="	--set console.techPreview=true  "
	fi
	helm install suse/console $CONSOLE_HELM_VERSION --name susecf-console --namespace stratos --values $AKSDEPLOYID/scf-config-values.yaml $OPTIONS  --set metrics.enabled=true $TECH_PREVIEW_OPTION --set kube.organization="cap"
	log-environment-helm
}
deploy-cap-metrics(){
	log-action "Installing METRICS  $METRICS_HELM_VERSION"

	local OPTIONS=""
	if [ "$REGION" == "yourzone" ];then
		OPTIONS=" --values $AKSDEPLOYID/stratos-metrics-values.yaml "
	fi

	helm install suse/metrics $METRICS_HELM_VERSION --name susecf-metrics --namespace=metrics --values $AKSDEPLOYID/scf-config-values.yaml $OPTIONS --set kube.organization="cap"
	log-environment-helm
}

deploy-azure-catalog(){
	log-action "Installing Azure Catalog"
	helm repo add svc-cat https://svc-catalog-charts.storage.googleapis.com ;
	helm repo update;
	helm install svc-cat/catalog --name catalog --namespace catalog --set apiserver.storage.etcd.persistence.enabled=true \
	--set apiserver.healthcheck.enabled=false --set controllerManager.healthcheck.enabled=false --set apiserver.verbosity=2 \
	--set controllerManager.verbosity=2
	log-environment-helm
}
create-azure-servicebroker(){

	export SUBSCRIPTION_ID=$(az account show | jq -r '.id')
	export REGION="$REGION"
	export SBRGNAME=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 8)-service-broker
	az group create --name ${SBRGNAME} --location ${REGION}
	echo SBRGNAME=${SBRGNAME}
	export SERVICE_PRINCIPAL_INFO="$(az ad sp create-for-rbac --name ${SBRGNAME})"
	save-envvar "export SBRGNAME=$SBRGNAME"
	save-envvar "export REGION=$REGION"
	save-envvar "export SERVICE_PRINCIPAL_INFO='$SERVICE_PRINCIPAL_INFO'"
	log-action "SB ResourceGroup Created $SBRGNAME"
}
delete-azure-servicebroker(){
	if [ ! "$REGION" == "yourzone" ]; then
			az group delete --name $1
	log-action "SB ResourceGroup Deleted $1"
	fi
}
deploy-azure-osba(){
	log-action "Installing Azure OSBA"
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
	log-environment-helm
}
deploy-minibroker(){
	log-action "Installing Minibroker"
	helm install suse/minibroker --namespace minibroker --name minibroker --set "defaultNamespace=minibroker"
	log-environment-helm
}
cf-create-minibroker-sb(){
	log-action "Creating CF SB for minibroker & declaring services"

	cf create-service-broker minibroker user pass http://minibroker-minibroker.minibroker.svc.cluster.local
	cf enable-service-access redis
	cf enable-service-access mongodb
	cf enable-service-access mariadb
	cf enable-service-access postgresql
	cf enable-service-access mysql
	cf create-security-group redis_networking  $AKSDEPLOYID/redis.json
	cf create-security-group mongo_networking  $AKSDEPLOYID/mongo.json
	cf create-security-group mysql_networking  $AKSDEPLOYID/mysql.json
# for network in 10.x
	cf create-security-group redis10_networking  $AKSDEPLOYID/redis10.json
	cf create-security-group mongo10_networking  $AKSDEPLOYID/mongo10.json
	cf create-security-group mysql10_networking  $AKSDEPLOYID/mysql10.json

	cf bind-security-group redis_networking testorg scftest
	cf bind-security-group mongo_networking testorg scftest
	cf bind-security-group mysql_networking testorg scftest
	cf bind-security-group redis10_networking testorg scftest
	cf bind-security-group mongo10_networking testorg scftest
	cf bind-security-group mysql10_networking testorg scftest
}
cf-set-api(){
echo "CFEP $CFEP"
	if [ -z "$CFEP" ]; then
		CFEP=$(awk '/Public IP:/{print "https://api." $NF ".xip.io"}' $AKSDEPLOYID/deployment.log)
	fi
	echo "CF Endpoint : $CFEP"
	cf api --skip-ssl-validation $CFEP
	ADMINPSW=$(awk '/CLUSTER_ADMIN_PASSWORD:/{print $NF}' $AKSDEPLOYID/scf-config-values.yaml)
	cf login -u admin -p $ADMINPSW
	log-action "CF Login to $CFEP"
}

cf-create-azure-sb(){
	log-action "Creating CF SB for Azure & declaring services"
	cf create-service-broker azure${REGION} $(kubectl get deployment osba-open-service-broker-azure \
	--namespace osba -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name == "BASIC_AUTH_USERNAME")].value}') $(kubectl get secret --namespace osba osba-open-service-broker-azure -o jsonpath='{.data.basic-auth-password}' | base64 -d) http://osba-open-service-broker-azure.osba
	cf service-access -b azure${REGION} | awk '($2 ~ /basic/)||($1 ~ /mongo/) { system("cf enable-service-access " $1 " -p " $2 " -b " brok)}/^broker/{brok=$NF}/^courtier/{brok=$NF}'
}
cf-create-org-space(){
	log-action "Creating CF Orgs & Spaces & target"

	cf create-org testorg;
	cf create-space scftest -o testorg;
	cf target -o "testorg" -s "scftest";
}
cf-create-service-mysql-ex1-az(){
	log-action "Creating scf-rails-example-db mysql service in Azure"
	cf create-service azure-mysql-5-7 basic scf-rails-example-db -c "{ \"location\": \"${REGION}\", \"resourceGroup\": \"${SBRGNAME}\", \"firewallRules\": [{\"name\": \"AllowAll\", \"startIPAddress\":\"0.0.0.0\",\"endIPAddress\":\"255.255.255.255\"}]}";
}
cf-create-service-mysql-ex1-mb(){
	log-action "Creating scf-rails-example-db mysql service in Minibroker"
	cf create-service mysql 5-7-14  scf-rails-example-db   -c '{"mysqlDatabase":"todos"}'
}
cf-create-service-mongodb-ex2-az(){
	log-action "Creating scf-mongo-db mongodb service in Azure"
	cf create-service azure-cosmosdb-mongo-account account scf-mongo-db -c "{ \"location\": \"${REGION}\", \"resourceGroup\": \"${SBRGNAME}\"}"
}
cf-create-service-mongodb-ex2-mb(){
	log-action "Creating scf-mongo-db mongodb service in Minibroker"
	cf create-service mongodb 4-0-8 scf-mongo-db
}
cf-wait-service-created(){
	log-action "Waiting for service $1 creation"
			 ## $1 Param : service Name expected
	echo "Wait for SCF 1st Service to be ready"
	PODSTATUS=$(cf service $1|awk "/^status:/{print \$NF}");
	while [ $PODSTATUS != "succeeded" ]; do
		sleep 20 ;
		PODSTATUS=$(cf service $1|awk "/^status:/{print \$NF}");
		echo "Status $PODSTATUS for db service";
	done
	log-action "Service $1 Successfully created"
}
azure-disable-ssl-mysql(){
	az mysql server list --resource-group $SBRGNAME|jq '.[] |select(.sslEnforcement=="Enabled")' |awk '/name.*-/{print "az mysql server update --resource-group $SBRGNAME --name " substr($2,2,length($2)-3) " --ssl-enforcement Disabled"}'|sh
	log-action "Mysql SSL disabled in Azure instances"
}
cf-deploy-rails-ex1(){
	log-action "Deploying application scf-rails-example"
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
	log-action "Application scf-rails-example deployed"$'\n'"$(cf apps)"
}
cf-deploy-nodejs-ex1(){
	log-action "Deploying application node-backbone-mongo"
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
	log-action "Application node-backbone-mongo deployed"$'\n'"$(cf apps)"
}
helm-delete-and-ns(){
    log-action "Deletion of $1 Helm deployment & $2 Namespace"
	kubectl delete ns $2 --grace-period=0 --force
	helm delete --purge $1
	log-environment
}
backup-cap(){
	newbackupid=CAP-BCK-`date +'%Y-%m-%d_%Hh%M'`
	export BCKLOC="$AKSDEPLOYID/backups/$newbackupid"
	log-action "Backup CAP in $BCKLOC started"
	if [ ! -d "$BCKLOC" ]; then
		mkdir -p $BCKLOC
    fi;
    log-action "Backup CAP in $BCKLOC Kubeconfig & CF API"
    kubectl config view --flatten >$BCKLOC/kubeconfig.yaml
    cf api >$BCKLOC/cfapi.log
	log-action "Backup CAP in $BCKLOC Blobstore"
	kubectl exec --stdin --tty blobstore-0 --namespace scf -- bash -c 'tar cfvz blobstore-src.tgz /var/vcap/store/shared';
	kubectl cp scf/blobstore-0:blobstore-src.tgz $BCKLOC/blobstore-src.tgz
	log-action "Backup CAP in $BCKLOC CCDB db content"
	kubectl exec -t mysql-0 --namespace scf -- bash -c \
		'/var/vcap/packages/mariadb/bin/mysqldump \
		--defaults-file=/var/vcap/jobs/mysql/config/mylogin.cnf \
		ccdb' > $BCKLOC/ccdb-src.sql
	log-action "Backup CAP in $BCKLOC UAADB db content"
	kubectl exec -t mysql-0 --namespace uaa -- bash -c \
		'/var/vcap/packages/mariadb/bin/mysqldump \
		--defaults-file=/var/vcap/jobs/mysql/config/mylogin.cnf \
		uaadb' > $BCKLOC/uaadb-src.sql

	log-action "Backup CAP in $BCKLOC DB Encryption Keys"
	kubectl exec -t api-group-0 --namespace scf -- bash -c 'echo $DB_ENCRYPTION_KEY' >$BCKLOC/enc_key.txt ;
    kubectl exec -it --namespace scf api-group-0 -- bash -c "cat /var/vcap/jobs/cloud_controller_ng/config/cloud_controller_ng.yml | grep -A 3 database_encryption" >>$BCKLOC/enc_key.txt
	log-action "Backup CAP in $BCKLOC Done"
	ls $BCKLOC -al
	save-envvar "export LAST_CAP_BACKUP=\"$BCKLOC\"" ;
}
list-backups(){
	echo "Last Backup : $LAST_CAP_BACKUP"
	echo "List of available Backups for this deployment"
	ls $AKSDEPLOYID/backups/ -al
}
select-backup-to-restore(){
	echo "List of available Backups for this deployment"
	echo "Select the one to restore"
	unset options i
	while IFS= read -r -d $'\0' f; do
	  options[i++]="$f"
	done < <(find $AKSDEPLOYID/backups/* -maxdepth 1 -type d -print0)
	select opt in "${options[@]}" "Select Last Backup" ; do
	  case $opt in
		*CAP*)
		  export CAP_RESTORE_LOCATION="$opt"
		  break
		  ;;
		"Select Last Backup")
		  export CAP_RESTORE_LOCATION="$LAST_CAP_BACKUP" 
		  break
		  ;;
		*)
		  echo "This is not a number"
		  ;;
	  esac
	done
	log-action "Restore CAP: $CAP_RESTORE_LOCATION Selected"
}
launch-restore(){
	log-action "Restore CAP from  $CAP_RESTORE_LOCATION Started"
	#        "Restore Change Domain Name in sql")
	#             vim $CAP_RESTORE_LOCATION/ccdb-src.sql
	log-action "Restore CAP : Restore Stop Monit Services"
	kubectl exec --stdin --tty --namespace scf api-group-0 -- bash -l -c 'monit stop all';
	kubectl exec --stdin --tty --namespace scf cc-worker-0 -- bash -l -c 'monit stop all';
	kubectl exec --stdin --tty --namespace scf cc-clock-0 -- bash -l -c 'monit stop all';

	log-action "Restore CAP : Restore inject blobstore"
	kubectl cp $CAP_RESTORE_LOCATION/blobstore-src.tgz scf/blobstore-0:. ;
	kubectl exec -it --namespace scf blobstore-0 -- bash -l -c 'monit stop all && sleep 10 && rm -rf /var/vcap/store/shared/* && tar xvf blobstore-src.tgz && monit start all && rm blobstore-src.tgz'

	log-action "Restore CAP : Restore CCDB Content"
	kubectl exec -t mysql-0 --namespace scf -- bash -c \
		"/var/vcap/packages/mariadb/bin/mysql \
		--defaults-file=/var/vcap/jobs/mysql/config/mylogin.cnf \
		-e 'drop database ccdb; create database ccdb;'";
	kubectl exec -i mysql-0 --namespace scf -- bash -c '/var/vcap/packages/mariadb/bin/mysql --defaults-file=/var/vcap/jobs/mysql/config/mylogin.cnf ccdb' < $CAP_RESTORE_LOCATION/ccdb-src.sql

	log-action "Restore CAP : Restore UAADB Content"
	kubectl exec -t mysql-0 --namespace uaa -- bash -c \
		"/var/vcap/packages/mariadb/bin/mysql \
		--defaults-file=/var/vcap/jobs/mysql/config/mylogin.cnf \
		-e 'drop database uaadb; create database uaadb;'";
	kubectl exec -i mysql-0 --namespace uaa -- bash -c '/var/vcap/packages/mariadb/bin/mysql --defaults-file=/var/vcap/jobs/mysql/config/mylogin.cnf uaadb' < $CAP_RESTORE_LOCATION/uaadb-src.sql

	log-action "Restore CAP : Start Monit Services"
	kubectl exec --stdin --tty --namespace scf api-group-0 -- bash -l -c 'monit start all';
	kubectl exec --stdin --tty --namespace scf cc-worker-0 -- bash -l -c 'monit start all';
	kubectl exec --stdin --tty --namespace scf cc-clock-0 -- bash -l -c 'monit start all';

	log-action "Restore CAP : Restore Change EncKey"
	kubectl exec -t --namespace scf api-group-0 -- bash -c 'sed -i "/db_encryption_key:/c\\db_encryption_key: \"$(echo $CC_DB_ENCRYPTION_KEYS | jq -r .migrated_key)\"" /var/vcap/jobs/cloud_controller_ng/config/cloud_controller_ng.yml'
	restore-key-rotation

	log-action "Restore CAP from  $CAP_RESTORE_LOCATION Done"
	}
restore-key-rotation(){
	log-action "Restore CAP : Key Rotation"
	kubectl exec --namespace scf api-group-0 -- bash -c 'source /var/vcap/jobs/cloud_controller_ng/bin/ruby_version.sh;export CLOUD_CONTROLLER_NG_CONFIG=/var/vcap/jobs/cloud_controller_ng/config/cloud_controller_ng.yml;cd /var/vcap/packages/cloud_controller_ng/cloud_controller_ng;bundle exec rake rotate_cc_database_key:perform'
	log-action "Restore CAP : Delete the Api-group-0 pod"
	kubectl -n scf delete pod api-group-0 --force --grace-period=0
}
restore-cap(){
	select-backup-to-restore
	echo "Ensure that the new CAP deployment is running properly, with same version & Encryption Keys are set in HELM values"
	while true; do
		read -p "Do you confirm the restore from $CAP_RESTORE_LOCATION?" yn
		case $yn in
			[Yy]* ) launch-restore; break;;
			[Nn]* ) break;;
			* ) echo "Please answer yes or no.";;
		esac
	done      
}

######## START OF EXEC

init-cap-deployment
select_cap-version

PS3='Please enter your choice: '
if [[ -z "${SUBSCRIPTION_ID}" ]]; then
    # not azure deployment
	options=("Quit" "Review scfConfig" "Review metricsConfig" "**Deploy ingress-controller" "**Prep New Cluster**" "Deploy UAA" "Pods UAA" \
	"Deploy SCF" "Pods SCF" \
	"CF API set" "CF CreateOrgSpace" \
       	"Deploy Minibroker SB" "CF 1st mysql Service" \
	"CF Wait for 1st Service Created" "Deploy 1st Rails Appl" \
	"Deploy Stratos SCF Console" "Pods Stratos" "Deploy Metrics" "Pods Metrics" \
	"CF 1st mongoDB Service" "CF Wait for mongoDB Service" "Deploy 2nd App Nodejs" \
	"All localk8S" "DELETE CAP"  "Upgrade Version" "Backup CAP" "Restore CAP")

else
    # AZURE set of actions
	options=("Quit" "Review scfConfig" "Review metricsConfig" "**Deploy ingress-controller" "**Prep New Cluster**" "Deploy UAA" "Pods UAA" \
	"Deploy SCF" "Pods SCF" "Deploy AZ CATALOG" "Pods AZ CATALOG" \
	"Create AZ SB" "Deploy AZ OSBA" "Pods AZ OSBA" "CF API set" \
	"CF Add AZ SB" "CF CreateOrgSpace" "CF 1st mysql Service" \
	"CF Wait for 1st Service Created" "AZ Disable SSL Mysql DBs" "Deploy 1st Rails Appl" \
	"Deploy Stratos SCF Console" "Pods Stratos" "Deploy Metrics" "Pods Metrics" \
	"CF 1st mongoDB Service" "CF Wait for mongoDB Service" "Deploy 2nd App Nodejs" \
	"All Azure" "DELETE CAP"  "Upgrade Version" "Backup CAP" "Restore CAP" )
 fi

select opt in "${options[@]}"
do
    case $opt in
        "Quit")
            break
            ;;
        "Review scfConfig")
            review-cap-config-file
            ;;
        "Review metricsConfig")
            review-metrics-config-file
            ;;
        "**Deploy ingress-controller")
	    deploy-ingress-controller
            ;;
        "**Prep New Cluster**")
            install-helm
            deploy-nfs-provisioner-local
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
                *)	break;;
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
			if [ ! "$REGION" == "yourzone" ]; then
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
			if [ ! "$REGION" == "yourzone" ]; then
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
            if [ "$CAP_VERSION" == "1.5.1RC1" ];then
                deploy-cap-scf-rc1
    	    else
                deploy-cap-uaa
                wait-for-pods-ready-of-ns uaa
    	        deploy-cap-scf
	    fi
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
			hlist=$(helm list -q																								)

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
		"Backup CAP")
			backup-cap
			;;
		"Restore CAP")
			restore-cap
                    ;;
	        "Restore KeyRotation")
		    restore-key-rotation
    		    ;;
        *) echo "invalid option $REPLY";;
    esac
done


