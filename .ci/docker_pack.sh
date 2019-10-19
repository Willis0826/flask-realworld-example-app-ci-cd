#!/bin/sh

# build with the folder's Dockerfile and push to latest and version
# exit immediately if a command exits with a non-zero status
set -e

log() {
    echo -e "\033[1;${1}m${2}\033[m"
}

pack() {
    local BUILD_PATH="$1"
    local IMAGE_REPO="$2"
    local VERSION=$CI_COMMIT_SHORT_SHA
    if [ ! -z $CI_COMMIT_TAG ]; then
        # if CI_COMMIT_TAG is not empty
        VERSION=$CI_COMMIT_TAG
    fi

    log 36 "Build Path: $BUILD_PATH"
    log 36 "Build Commit: $CI_COMMIT_SHORT_SHA"
    log 36 "CI Commit Tag: $CI_COMMIT_TAG"
    log 36 "Build Version: $VERSION"
    log 36 "Image Repo: $IMAGE_REPO"

    # pull first for build cache
    log 36 "* Pulling Image..."
    docker pull $IMAGE_REPO:latest
    log 36 "* Building Image..."
    docker build --pull --cache-from $IMAGE_REPO:latest \
        -t $IMAGE_REPO:latest \
        -t $IMAGE_REPO:$VERSION \
        $BUILD_PATH
    log 36 "* Pushing Image..."
    # push in CI only
    if [ ! -z $GITLAB_CI ]; then
        docker push $IMAGE_REPO:latest
        docker push $IMAGE_REPO:$VERSION
    fi
}

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: `basename $0` <build-path> <image-repo>"
    exit 1
fi

pack "$@"

exit 0
