#!/bin/sh

# build with the folder's Dockerfile and push to latest and version
# exit immediately if a command exits with a non-zero status
set -e

log() {
    echo -e "\033[1;${1}m${2}\033[m"
}

deploy() {
    local DEPLOY_BASE="$1"
    local DEPLOY_FOLDER="$2"
    local CLUSTER_NAME="$3"
    log 36 "Deploy Base: $DEPLOY_BASE"
    log 36 "Deploy Floder: $DEPLOY_FOLDER"
    log 36 "Cluster Name $CLUSTER_NAME"
    # gomplate replace setting
    VERSION=$VERSION gomplate --input-dir=$DEPLOY_BASE/$DEPLOY_FOLDER \
        --output-dir=$DEPLOY_BASE/dist/$DEPLOY_FOLDER
    # kops replace --force
    kops replace -f $DEPLOY_BASE/dist/$DEPLOY_FOLDER/cluster.yaml --force
    kops replace -f $DEPLOY_BASE/dist/$DEPLOY_FOLDER/ig.yaml --force
    # kops update --yes
    kops update cluster $CLUSTER_NAME --yes
    # kops validate
    kops_validate_cluster_ready $CLUSTER_NAME
}

kops_validate_cluster_ready() {
    local CLUSTER_NAME="$1"
    log 33 "* Wait for the cluster to be ready, $CLUSTER_NAME"
    until kops validate cluster --name $CLUSTER_NAME; do
        sleep 20
    done
}

deploy "$@"

exit 0
