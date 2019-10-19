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
    local VERSION=$CI_COMMIT_SHORT_SHA
    if [ ! -z $CI_COMMIT_TAG ]; then
        # if CI_COMMIT_TAG is not empty
        VERSION=$CI_COMMIT_TAG
    fi
    # gomplate replace setting
    VERSION=$VERSION gomplate --input-dir=$DEPLOY_BASE/$DEPLOY_FOLDER \
        --output-dir=$DEPLOY_BASE/dist/$DEPLOY_FOLDER
    # k8s deploy
    kubectl apply -Rf $DEPLOY_BASE/dist/$DEPLOY_FOLDER
}

deploy "$@"

exit 0
