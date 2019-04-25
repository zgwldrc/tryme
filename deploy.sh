#!/bin/sh
# we assume there is a file named deploy_list under current working directory
# BUILD_EXCLUDE_LIST
# DEPLOY_EXCLUDE_LIST
# REGISTRY
# REGISTRY_USER
# REGISTRY_PASSWD
# REGISTRY_NAMESPACE
# DOCKERFILE_URL
# APP_INFOS_URL
# BUILD_LIST
# ${CI_COMMIT_SHA:0:8}

if [ ! -e deploy_list ];then
    echo deploy_list not found 
    exit 1
fi

awk '{print $1,$1}' deploy_list | while read app app_instance;do
    kubectl set image deploy $app $app_instance=$REGISTRY/$REGISTRY_NAMESPACE/$app:${CI_COMMIT_SHA:0:8} || true
done
 