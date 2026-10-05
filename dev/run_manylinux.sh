#!/usr/bin/env bash

set -e

MODE=build # either (build | run)
DOCKER_IMAGE=mujoco-manylinux:latest

REPO_ROOT=$(git rev-parse --show-toplevel)
cd ${REPO_ROOT}

MODE_USER=""
while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help) SHOW_HELP=true; shift ;;
    --mode) MODE_USER="$2"; shift 2 ;;
    --verbose) VERBOSE=true; shift ;;
    *) echo "Unkown option: $1"; exit 1 ;;
    esac
done

command -v fzf >/dev/null 2>&1 && HAS_FZF=true || HAS_FZF=false

modes=(
    "build"
    "run"
)
if [[ "$HAS_FZF" == true && ! -n "$MODE_USER" ]]; then
    MODE=$(printf "%s\n" "${modes[@]}" | fzf --header="Select mode:" --layout=reverse)
else
    MODE=$MODE_USER
fi

case "$MODE" in
    build)
        echo "Building docker image ..."
        docker buildx build \
            -t $DOCKER_IMAGE \
            -f dev/build_manylinux.Dockerfile \
            . --platform linux/amd64
        ;;
    run)
        echo "Running docker container ..."
        docker run -it --rm \
            -v $(pwd)/python/dist/:/mujoco/python/dist/ \
            ${DOCKER_IMAGE}
        ;;
    *) echo "Invalid mode ${MODE}, must be one of (build|run)"; exit 1 ;;
esac
