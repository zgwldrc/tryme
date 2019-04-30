#!/bin/sh
# 作者: 夏禹
# 邮箱: zgwldrc@163.com
# 运行环境: zgwldrc/kubectl:v1.11.7
# K8S Deployment Script For Single Module Project Used in Gitlab-CI
# Env Var Must
# NAMESPACE
# KUBECONFIG_CONTENT
# REGISTRY
# REGISTRY_NAMESPACE
# APP_NAME
# CI_COMMIT_SHA


# 必要的环境变量
ENV_CHECK_LIST='
NAMESPACE
KUBECONFIG_CONTENT
REGISTRY
REGISTRY_NAMESPACE
APP_NAME
CI_COMMIT_SHA
'

function check_env(){
  local r
  for i do
    eval "r=\${${i}:-undefined}"
    if [ "$r" == "undefined" ];then
      echo "$i is not defined"
      exit 1
    fi
  done
}

function _init_env(){
    mkdir -p $HOME/.kube/
    echo -e "$KUBECONFIG_CONTENT" > $HOME/.kube/config
    kubectl config set-context `kubectl config current-context` --namespace=$NAMESPACE
}

check_env $ENV_CHECK_LIST
_init_env

kubectl set image deploy $APP_NAME $APP_NAME=$REGISTRY/$REGISTRY_NAMESPACE/$APP_NAME:${CI_COMMIT_SHA:0:8}
