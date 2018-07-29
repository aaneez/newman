#!/bin/bash

# Bail out on the first error
set -e;

BLUE='\033[0;34m';
NO_COLOUR='\033[0m';
DOCKER_USER="postman";
TAG=${npm_package_version};
IMAGES_BASE_PATH="./docker/images";

# It's good to be paranoid
[[ -z "$TAG" ]] && TAG=$(jq -r ".version" < package.json);

function build_docker_image {
    local TAG="$2";
    local BASENAME=$(basename $1);
    local IMAGE_NAME="newman_$BASENAME";
    local GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD);

    echo "";

    if [[ ${GIT_BRANCH} = "master" ]]; then
        echo -e "$BLUE Building docker image for $DOCKER_USER/$IMAGE_NAME:$TAG, latest $NO_COLOUR";
    else
        echo -e "$BLUE Building docker image for $DOCKER_USER/$IMAGE_NAME:$TAG $NO_COLOUR";
    fi

    if [[ ${GIT_BRANCH} = "master" ]]; then
        docker build \
            --no-cache --force-rm --squash \
            -t "$DOCKER_USER/$IMAGE_NAME:$TAG" -t "$DOCKER_USER/$IMAGE_NAME:latest" \
            --file="docker/images/$BASENAME/Dockerfile" --build-arg NEWMAN_VERSION="$TAG" .;
    else
        docker build \
            --no-cache --force-rm --squash \
            -t "$DOCKER_USER/$IMAGE_NAME:$TAG" \
            --file="docker/images/$BASENAME/Dockerfile" --build-arg NEWMAN_VERSION="$TAG" .;
    fi

    if [[ ${GIT_BRANCH} = "master" ]]; then
        echo -e "$BLUE Running docker image test for $DOCKER_USER/$IMAGE_NAME:$TAG, latest $NO_COLOUR";
    else
        echo -e "$BLUE Running docker image test for $DOCKER_USER/$IMAGE_NAME:$TAG $NO_COLOUR";
    fi

    docker run -v "$PWD/examples:/etc/newman" -t "$DOCKER_USER/$IMAGE_NAME:$TAG" run "sample-collection.json";

    # prepare current images for pushing
    docker tag "$DOCKER_USER/$IMAGE_NAME:$TAG" "$DOCKER_USER/$IMAGE_NAME:$TAG";

    if [[ ${GIT_BRANCH} = "master" ]]; then
        docker tag "$DOCKER_USER/$IMAGE_NAME:latest" "$DOCKER_USER/$IMAGE_NAME:latest";
    fi

    if [[ ${GIT_BRANCH} = "master" ]]; then
        echo -e "$BLUE Pushing docker image for $DOCKER_USER/$IMAGE_NAME:$TAG, latest $NO_COLOUR";
    else
        echo -e "$BLUE Pushing docker image for $DOCKER_USER/$IMAGE_NAME:$TAG $NO_COLOUR";
    fi

    docker push "$DOCKER_USER/$IMAGE_NAME:$TAG";

    if [[ ${GIT_BRANCH} = "master" ]]; then
        docker push "$DOCKER_USER/$IMAGE_NAME:latest";
    fi
}

for image in ${IMAGES_BASE_PATH}/*; do
    build_docker_image ${image} ${TAG};
done
