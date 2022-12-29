#!/usr/bin/env bash

ROOTDIR=$(pwd)
env=$1
SERVICE=$(basename $(pwd))
echo "RootDIR is: ${ROOTDIR}"
echo "env pass is: ${env}"
echo "SERVICE is: ${SERVICE}"

if [[ ! -f ${env}.tfvars ]]
then
   echo 'if condition true'
   find ${ROOTDIR}/base/_*.tf -exec ln -s {} . ';'
   ln -s ../base/environment/${env}.tfvars
fi
##to run this script.. /bin/bash ./runner.sh prod