# CAPandMore
SCF deploy automation
The main script is launched to deploy CAP SCF on a kubernetes cluster deployed before.
To deploy, 
Create/modify a new initxxxx.sh file
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

