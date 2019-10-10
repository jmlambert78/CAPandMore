# CAPnMore : SCF deployment automation

Introduction
---
The main script **capnmore.sh** is launched to deploy CAP SCF on a kubernetes cluster deployed before.
To deploy, ensure that you **access a K8S cluster & prepare a PV provisionner (NFS or other)**

>If you are in AKS, you will need to provide more elements (revision to come) (Subscription etc)

>NB: If you deployed with the https://github.com/jmlambert78/deploy-cap-aks-cluster mechanism, this deployment is compatible and will reuse envvars defined in the previous process (deploy AKS) (and especially the deploy-cap-aks-cluster/init_aks_env.sh )

**CAPnMore** allows you to manage **multiple deployments in several K8S clusters**, and stores specific deployment files in a subdir as below.

You will have one **initxxxx.sh per deployment directory** to help you switch between clusters

ex: You create a **CAP12345** subdir & an **init12345.sh** with the AKSDEPLOYID containing the path to that CAP12345 dir.
    You create a **CAP98765** subdir & an **init98765.sh** with the AKSDEPLOYID containing the path to that CAP98765 dir.

You will **source init12345.sh or init98765.sh** to select your deployment environment prior to launch the **capnmore.sh** script


Prerequisites:
---
- HELM client
- CF client
- kubectl client
- Wildcard DNS entry for your CAP urls like (cf.capjmlzone.com)


Create/modify a new initxxxx.sh file (if you have not the above init_aks_env.sh for AKS)
------------------------------
```
#!/bin/bash
export AKSDEPLOYID="$PWD/CAP-080819"  #<- Create a new dir where CAPnMore will set all working files
export REGION="yourzone"
export KUBECONFIG="$AKSDEPLOYID/kubeconfig" #<- Copy your kube config file here under kubeconfig
export CF_HOME="$AKSDEPLOYID/cfconfig"      #<- will be used to store Cloudfoundry setups (to allow multi clusters)
CFEP="https://api.cf.cap2jmlzone.com"     # here is the URL of your CF deployment (in coord with the SCF-VALUES.YAML file)
echo "export CFEP=$CFEP" >>$AKSDEPLOYID/.envvar.sh  # this .envvar.sh will memorise the envvars if work is done in multisteps
cf api --skip-ssl-validation $CFEP      # this will just try to connect to the CF API endpoint
```
Source this initxxxx.sh file to get the variables ready
-------------------------------------------------------
**source initxxxx.sh**
NB: Use source to have the ENVVARs setup at your shell level and be able to use the kubectl/cf in your shell

Create the Deployment directory if not existing
-------------------------------------------
mkdir $AKSDEPLOYID

Populate the Deployment directory with templates files
-------------------------------------------
Copy the **Templates** directoy into your own choosen $AKSDEPLOYID diretory
Add the **kubeconfig** file with your kubernetes config file content 

Edit your SCF deployment helm chart values (scf, stratos...)
-----------
```
vim $AKSDEPLOYID/scf-config-values.yaml
vim $AKSDEPLOYID/ stratos-metrics-values.yaml
-> update all params, as you need
```
Test your configuration with kubectl
--------
```
kubectl get nodes # check that it is your k8S cluster
```
Launch the capnmore.sh script
-----
./capnmore.sh
```
>>>>>> Welcome to the CAPnMORE deployment tool <<<<<<<
NAME         STATUS   ROLES    AGE   VERSION
caasp3m141   Ready    master   2d    v1.10.11
caasp3n142   Ready    <none>   2d    v1.10.11
caasp3n143   Ready    <none>   2d    v1.10.11
 Current selected version : 
1) 1.3.0
2) 1.3.1
3) 1.4.0
4) 1.4.1
Please enter your choice:     <- Select the Version of CAP you want to deploy    
 Current selected version : 1.4.1
1) Quit                              10) CF API set                       19) CF 1st mongoDB Service
2) Review scfConfig                  11) CF CreateOrgSpace                20) CF Wait for mongoDB Service
3) Review metricsConfig              12) CF 1st mysql Service             21) Deploy 2nd App Nodejs
4) **Prep New Cluster**              13) CF Wait for 1st Service Created  22) All localk8S
5) Deploy UAA                        14) Deploy 1st Rails Appl            23) DELETE CAP
6) Pods UAA                          15) Deploy Stratos SCF Console       24) Upgrade Version
7) Deploy SCF                        16) Pods Stratos                     25) Backup CAP
8) Pods SCF                          17) Deploy Metrics                   26) Restore CAP
9) Deploy Minibroker SB              18) Pods Metrics

Please enter your choice:
```
IF YOU ARE ON AZURE deployment :
```
>>>>>> Welcome to the CAPnMORE deployment tool <<<<<<<
NAME                       STATUS   ROLES   AGE   VERSION
aks-jmlpool19-14921831-0   Ready    agent   38h   v1.12.8
aks-jmlpool19-14921831-1   Ready    agent   38h   v1.12.8
aks-jmlpool19-14921831-2   Ready    agent   38h   v1.12.8
 Current selected version 1.4.1
 1) Quit                             11) Pods AZ OSBA                     21) Deploy Metrics
 2) Review scfConfig                 12) CF API set                       22) Pods Metrics
 3) Deploy UAA                       13) CF Add AZ SB                     23) CF 1st mongoDB Service
 4) Pods UAA                         14) CF CreateOrgSpace                24) CF Wait for mongoDB Service
 5) Deploy SCF                       15) CF 1st mysql Service             25) Deploy 2nd App Nodejs
 6) Pods SCF                         16) CF Wait for 1st Service Created  26) All Azure
 7) Deploy AZ CATALOG                17) AZ Disable SSL Mysql DBs         27) DELETE CAP
 8) Pods AZ CATALOG                  18) Deploy 1st Rails Appl            28) Upgrade Version
 9) Create AZ SB                     19) Deploy Stratos SCF Console       29) Backup CAP
10) Deploy AZ OSBA                   20) Pods Stratos                     30) Restore CAP
Please enter your choice:
```

Select the Action or set of actions from the menu entries.
----

- Option "All localK8S" will launch sequentially most steps to deploy CAP on a kubernetes cluster for which you 
- Option "DELETE CAP" will delete all helm charts of SCF & remove the Namespaces as well
- Pods XXX : display the pods status in kubectl format
- Upgrade Version : will process the upgrade path from the current version to the next possible
    1.3.0 -> 1.3.1 -> 1.4.0 -> 1.4.1
- AZ options are specific to AKS
- All Azure : Will launch sequentially most steps to deploy CAP on a AKS cluster
- Minibroker is useful for local K8S to deliver local service instances (mongo, mysql, postgres, redis, mariadb)

If you want to deploy manually, step by step, you may select actions, the context is preserved from one step to another even if you exit. (just source the initxxxx.sh file before launching the capnmore.sh)

Logging of your actions : history
---
Each task launched is tracked in an historyfile : 

```
2019-08-09_08h47: Launch CAPnMore : Current selected version 1.4.1
2019-08-09_08h47: vvvvvv Current environment :
2019-08-09_08h47: PWD: /home/jmlambert/azure-cap/deploy-cap-aks-cluster-jml
>>> kubectl get nodes <<<
NAME                       STATUS   ROLES   AGE   VERSION
aks-jmlpool19-14921831-0   Ready    agent   38h   v1.12.8
aks-jmlpool19-14921831-1   Ready    agent   38h   v1.12.8
aks-jmlpool19-14921831-2   Ready    agent   38h   v1.12.8
>>> helm list <<<
NAME            REVISION        UPDATED                         STATUS          CHART                           NAMESPACE
catalog         1               Thu Aug  8 11:57:25 2019        DEPLOYED        catalog-0.2.1                   catalog
osba            1               Thu Aug  8 11:59:20 2019        DEPLOYED        open-service-broker-azure-1.8.2 osba
susecf-console  1               Thu Aug  8 16:58:34 2019        DEPLOYED        console-2.4.0                   stratos
susecf-scf      1               Thu Aug  8 11:46:33 2019        DEPLOYED        cf-2.17.1                       scf
susecf-uaa      1               Thu Aug  8 11:40:39 2019        DEPLOYED        uaa-2.17.1                      uaa
>>> kubectl get ns <<<
NAME          STATUS   AGE
catalog       Active   20h
default       Active   38h
kube-public   Active   38h
kube-system   Active   38h
osba          Active   20h
scf           Active   21h
stratos       Active   15h
uaa           Active   21h
2019-08-09_08h47: ^^^^^^ Current environment
```    
> You may also have a shorter history : ./simple-history.sh
```
2019-08-09_09h51: Launch CAPnMore : Current selected version
2019-08-09_09h51: CAP version  defined
2019-08-09_09h51: Installing UAA   --version 2.17.1
2019-08-09_09h51: Wait for pods readiness for uaa
2019-08-09_09h55: All pods ready for uaa
2019-08-09_09h55: Installing SCF   --version 2.17.1
2019-08-09_09h55: Wait for pods readiness for scf
2019-08-09_10h05: All pods ready for scf
2019-08-09_10h05: CF Login to https://api.cf.cap2jmlzone.com
2019-08-09_10h05: Creating CF Orgs & Spaces & target
2019-08-09_10h05: Installing Minibroker
2019-08-09_10h05: Wait for pods readiness for minibroker
2019-08-09_10h05: All pods ready for minibroker
2019-08-09_10h05: Creating CF SB for minibroker & declaring services
2019-08-09_10h06: Creating scf-rails-example-db mysql service in Minibroker
2019-08-09_10h06: Waiting for service scf-rails-example-db creation
2019-08-09_10h06: Service scf-rails-example-db Successfully created
2019-08-09_10h06: Deploying application scf-rails-example
2019-08-09_10h07: Application scf-rails-example deployed
2019-08-09_10h07: Installing STRATOS   --version 2.4.0
2019-08-09_10h07: Wait for pods readiness for stratos
2019-08-09_10h08: All pods ready for stratos
2019-08-09_10h08: Installing METRICS
2019-08-09_10h08: Wait for pods readiness for metrics
2019-08-09_10h13: All pods ready for metrics
2019-08-09_10h13: Creating scf-mongo-db mongodb service in Minibroker
2019-08-09_10h13: Waiting for service scf-mongo-db creation
2019-08-09_10h13: Service scf-mongo-db Successfully created
2019-08-09_10h13: Deploying application node-backbone-mongo
2019-08-09_10h13: Application node-backbone-mongo deployed
```




To Do :
----
- ~~Deploy NFS Provisionner (needed to provide PVs in the local K8S)
- ~~Install HELM if not done in your cluster (rbac + tiller)
- ~~Integrate the CAP Backup/Restore options
- Integrate the SCALING options for SCF/UAA
- ~~Integrate the log of all actions in a file
- ~~Reorg the labels (too many ;-)


