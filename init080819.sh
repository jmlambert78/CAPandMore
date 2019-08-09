#!/bin/bash
export AKSDEPLOYID="$PWD/CAP-080819"
export REGION="yourzone"
export KUBECONFIG="$AKSDEPLOYID/kubeconfig"
export CF_HOME="$AKSDEPLOYID/cfconfig"
export PS1="\u:\w:$AKSDEPLOYID>\[$(tput sgr0)\]"

export PS1="\w:>\[$(tput sgr0)\]"

#CFEP=$(awk '/Public IP:/{print "https://api." $NF ".xip.io"}' $AKSDEPLOYID/deployment.log)
CFEP="https://api.cf.cap2jmlzone.com"

echo "export CFEP=\"$CFEP\"" >>$AKSDEPLOYID/.envvar.sh

cf api --skip-ssl-validation $CFEP

