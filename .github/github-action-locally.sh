#!/bin/bash

KUBECONFIG=$1

# brew install act
uNames=`uname -s`
if [ "$uNames" == "Darwin" ]; then
  if ! [ -x "$(command -v act)" ]; then
    echo "brew install act"
    brew install act
  fi
fi

# get kube config
if [[ -z $KUBECONFIG ]]; then
  KUBECONFIG=~/.kube/config
fi
cp $KUBECONFIG .github/kubeconfig

# run act
act -P self-hosted=jashbook/github-runner:latest

rm -rf .github/kubeconfig