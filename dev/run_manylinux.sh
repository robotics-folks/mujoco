#!/usr/bin/env bash

set -e

MODE=build # either (build | run)
IMAGE_NAME=mujoco-manylinux

REPO_ROOT=$(git rev-parse --show-toplevel)
cd ${REPO_ROOT}

MODE_USER=""
DEV=false
NO_CACHE=false

while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help) SHOW_HELP=true; shift ;;
    --mode) MODE_USER="$2"; shift 2 ;;
    --dev) DEV=true; shift ;;
    --no-cache) NO_CACHE=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    *) echo "Unkown option: $1"; exit 1 ;;
    esac
done

command -v fzf >/dev/null 2>&1 && HAS_FZF=true || HAS_FZF=false
command -v podman >/dev/null 2>&1 && HAS_PODMAN=true || HAS_PODMAN=false

[[ "$DEV" == "true" ]] && DOCKER_IMAGE="${IMAGE_NAME}:dev" || DOCKER_IMAGE="${IMAGE_NAME}:latest"
[[ "$DEV" == "true" ]] && DOCKER_FILE="build_manylinux_dev.Dockerfile" || DOCKER_FILE="build_manylinux.Dockerfile"
[[ "$DEV" == "true" ]] && MOUNT_CMD="-v $(pwd)/:/mujoco/" || MOUNT_CMD="-v $(pwd)/python/dist/:/mujoco/python/dist/"

dockerish_build_cmd="docker buildx build"
dockerish_run_cmd="docker run"
if [[ "${HAS_PODMAN}" == "true" ]]; then
    dockerish_build_cmd="podman build"
    dockerish_run_cmd="podman run"
fi

modes=(
    "build"
    "run"
)
if [[ "$HAS_FZF" == true && ! -n "$MODE_USER" ]]; then
    MODE=$(printf "%s\n" "${modes[@]}" | fzf --header="Select mode:" --layout=reverse)
else
    MODE=$MODE_USER
fi

[[ "$NO_CACHE" == "true" ]] && NO_CACHE_CMD="--no-cache" || NO_CACHE_CMD=""

case "$MODE" in
    build)
        echo "Building docker image ..."
        ${dockerish_build_cmd} $NO_CACHE_CMD \
            -t $DOCKER_IMAGE \
            -f dev/$DOCKER_FILE \
            . --platform linux/amd64
        ;;
    run)
        echo "Running docker container ..."
        ${dockerish_run_cmd} -it --rm --network host \
            ${MOUNT_CMD} \
            ${DOCKER_IMAGE}
        ;;
    *) echo "Invalid mode ${MODE}, must be one of (build|run)"; exit 1 ;;
esac
