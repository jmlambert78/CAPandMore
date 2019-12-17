#!/bin/bash
export AKSDEPLOYID="$PWD/CAP-AZURE-171219"
export REGION="westeurope"
export KUBECONFIG="$AKSDEPLOYID/kubeconfig"
export CF_HOME="$AKSDEPLOYID/cfconfig"
export PS1="\u:\w:$AKSDEPLOYID>\[$(tput sgr0)\]"

export PS1="\w:>\[$(tput sgr0)\]"

#CFEP=$(awk '/Public IP:/{print "https://api." $NF ".xip.io"}' $AKSDEPLOYID/deployment.log)
CFEP="https://api.cf1.jmllabsuse.com:443"

echo "export CFEP=\"$CFEP\"" >>$AKSDEPLOYID/.envvar.sh

cf api --skip-ssl-validation $CFEP

