#!/bin/sh

# build with the folder's Dockerfile and push to latest and version
# exit immediately if a command exits with a non-zero status
set -e

log() {
    echo -e "\033[1;${1}m${2}\033[m"
}

kops_delete_cluster() {
    local DEPLOY_BASE="$1"
    local DEPLOY_FOLDER="$2"
    local CLUSTER_NAME="$3"
    log 33 "Start to update cluster, $CLUSTER_NAME"
    # gomplate replace setting
    VERSION=$VERSION gomplate --input-dir=$DEPLOY_BASE/$DEPLOY_FOLDER \
        --output-dir=$DEPLOY_BASE/dist/$DEPLOY_FOLDER
    # kops replace --force
    kops replace -f $DEPLOY_BASE/dist/$DEPLOY_FOLDER/cluster.yaml --force
    kops replace -f $DEPLOY_BASE/dist/$DEPLOY_FOLDER/ig.yaml --force
    # kops update --yes
    kops update cluster $CLUSTER_NAME --yes
    # kops delete
    log 33 "Start to delete cluster, $CLUSTER_NAME"
    kops delete cluster $CLUSTER_NAME --yes
}

kops_delete_cluster "$@"

exit 0
