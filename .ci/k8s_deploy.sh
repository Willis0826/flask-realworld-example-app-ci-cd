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
    log 36 "Deploy Base: $DEPLOY_BASE"
    log 36 "Deploy Floder: $DEPLOY_FOLDER"
    log 36 "Version: $VERSION"
    if [ ! -z $CI_COMMIT_TAG ]; then
        # if CI_COMMIT_TAG is not empty
        log 36 "CI_COMMIT_TAG: $CI_COMMIT_TAG"
        log 36 "Overwrite version with tag"
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
