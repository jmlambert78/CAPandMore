# CAPandMore : SCF deploy automation

The main script is launched to deploy CAP SCF on a kubernetes cluster deployed before.
To deploy, ensure that you access a K8S cluster & prepare a PV provisionner (NFS or other)

If you are in AKS, you will need to provide more elements (revision to come) (Subscription etc)
NB: If you deployed with the https://github.com/jmlambert78/deploy-cap-aks-cluster mechanism, this deployment is compatible and will reuse envvars defined in the previous process (deploy AKS) (and especially the deploy-cap-aks-cluster/init_aks_env.sh )

Create/modify a new initxxxx.sh file (if you have not the above init_aks_env.sh for AKS)
------------------------------

    #!/bin/bash
    export AKSDEPLOYID="$PWD/CAP-080819"  #<- Create a new dir where CAPandMore will set all working files
    export REGION="jmlzone"
    export KUBECONFIG="$AKSDEPLOYID/kubeconfig" #<- Copy your kube config file here under kubeconfig
    export CF_HOME="$AKSDEPLOYID/cfconfig"      #<- will be used to store Cloudfoundry setups (to allow multi clusters)
    CFEP="https://api.cf.cap2jmlzone.com"     # here is the URL of your CF deployment (in coord with the SCF-VALUES.YAML file)
    echo "export CFEP=$CFEP" >>$AKSDEPLOYID/.envvar.sh  # this .envvar.sh will memorise the envvars if work is done in multisteps
    cf api --skip-ssl-validation $CFEP      # this will just try to connect to the CF API endpoint

Source this initxxxx.sh file to get the variables ready
-------------------------------------------------------
source initxxxx.sh

Create the working directory if not existing
-------------------------------------------
mkdir $AKSDEPLOYID

Edit your SCF deployment helm chart values (scf, stratos...)
-----------
vim $AKSDEPLOYID/scf-config-values.yaml
vim $AKSDEPLOYID/ stratos-metrics-values.yaml
-> update all params, as you need

Test your configuration with kubectl
--------
kubectl get nodes # check that it is your k8S cluster

Launch the CAPandMore.sh script
-----
./CAPandMore.sh

    >>>>>> Welcome to the CAPandMORE deployment tool <<<<<<<
    NAME         STATUS   ROLES    AGE   VERSION
    caasp3m141   Ready    master   2d    v1.10.11
    caasp3n142   Ready    <none>   2d    v1.10.11
    caasp3n143   Ready    <none>   2d    v1.10.11
     Current installed version
    1) 1.3.0
    2) 1.3.1
    3) 1.4.0
    4) 1.4.1
    Please enter your choice:     <- Select the Version of CAP you want to deploy
---    
    Current installed version 1.4.1
     1) Quit                             11) Pods AZ OSBA                     21) Pods Stratos
     2) Review scfConfig                 12) Deploy Minibroker SB             22) Deploy Metrics
     3) Deploy UAA                       13) CF API set                       23) Pods Metrics
     4) Pods UAA                         14) CF Add AZ SB                     24) CF 1st mongoDB Service
     5) Deploy SCF                       15) CF CreateOrgSpace                25) CF Wait for mongoDB Service
     6) Pods SCF                         16) CF 1st mysql Service             26) Deploy 2nd App Nodejs
     7) Deploy AZ CATALOG                17) CF Wait for 1st Service Created  27) All Azure
     8) Pods AZ CATALOG                  18) AZ Disable SSL Mysql DBs         28) All localk8S
     9) Create AZ SB                     19) Deploy 1st Rails Appl            29) DELETE CAP
    10) Deploy AZ OSBA                   20) Deploy Stratos SCF Console       30) Upgrade Version
    Please enter your choice:

Select the Action or set of actions from the menu entries.
Option "All localK8S" will launch sequentially most steps to deploy CAP on a kubernetes cluster for which you 



To Do :
- Reorg the labels (too many ;-) 
- Deploy NFS Provisionner (needed to provide PVs in the local K8S)
- Install HELM if not done in your cluster (rbac + tiller)
- Integrate the CAP Backup/Restore options
- Integrate the SCALING options for SCF/UAA
- Integrate the log of all actions in a file 



