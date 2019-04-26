#!/bin/bash
function _check_env(){
    case "" in
    "$NAMESPACE"|"$KUBECONFIG_CONTENT")
        echo "must set env: NAMESPACE and KUBECONFIG"
        exit 1
        ;;
    *)
       ;;
   esac
}

function _init_env(){
    mkdir -p $HOME/.kube/
    echo -e "$KUBECONFIG_CONTENT" > $HOME/.kube/config
    kubectl config set-context `kubectl config current-context` --namespace=$NAMESPACE
}

_check_env
_init_env
