#!/usr/bin/env bash

set -e

MODE=build # either (build | run)
DOCKER_IMAGE=mujoco-manylinux:latest

REPO_ROOT=$(git rev-parse --show-toplevel)
cd ${REPO_ROOT}

MODE_USER=""
NO_CACHE=false

while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help) SHOW_HELP=true; shift ;;
    --mode) MODE_USER="$2"; shift 2 ;;
    --no-cache) NO_CACHE=true; shift ;;
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

[[ "$NO_CACHE" == "true" ]] && NO_CACHE_CMD="--no-cache" || NO_CACHE_CMD=""

case "$MODE" in
    build)
        echo "Building docker image ..."
        docker buildx build $NO_CACHE_CMD \
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
