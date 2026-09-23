#!/usr/bin/env bash

set +e

git status > /dev/null 2>&1
if [ $? -ne 0 ]; then
    ROOT_DIR=$(pwd)
else
    echo "Going back to the root of the project"
    ROOT_DIR="$(git rev-parse --show-toplevel)"
fi

set -e

build_type="Release"

cd ${ROOT_DIR}

CCACHE_ARGS=""
if command -v ccache >/dev/null 2>&1; then
    CCACHE_ARGS="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
fi

SHOW_HELP=false
build_filament=OFF
build_vulkan=OFF
build_studio=OFF
build_simulate=ON
install_dir=""
njobs=4
fresh=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) SHOW_HELP=true; shift ;;
        --debug) build_type="Debug"; shift ;;
        --rel-with-deb) build_type="RelWithDebInfo"; shift ;;
        --filament) build_filament=ON; shift ;;
        --vulkan) build_vulkan=ON; shift ;;
        --studio) build_studio=ON; shift ;;
        --njobs) njobs="$2"; shift 2 ;;
        --fresh) fresh=true; shift ;;
        --build-dir) build_dir="$2"; shift 2 ;;
        --install-dir) install_dir="$2"; shift 2 ;;
        *) echo "Unkown option: $1"; exit 1 ;;
    esac
done

if [[ "${build_filament}" == "ON" ]]; then
    build_simulate=OFF
fi

[[ -n $install_dir ]] && USER_INSTALL_DIR="${install_dir}" || USER_INSTALL_DIR="${ROOT_DIR}/install"

if [ ! -d "${USER_INSTALL_DIR}" ]; then
    mkdir -p $USER_INSTALL_DIR
fi

[ "$fresh" == "true" ] && FRESH_CMD="--fresh" || FRESH_CMD=""

# Configuration ---------------------------------------------------------

echo "Configuring ..."

cmake $FRESH_CMD -S . -B build \
    -DCMAKE_BUILD_TYPE=${build_type} \
    -DUSE_STATIC_LIBCXX=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DMUJOCO_BUILD_EXAMPLES=OFF \
    -DMUJOCO_BUILD_DEV_EXAMPLES=OFF \
    -DMUJOCO_BUILD_SIMULATE=${build_simulate} \
    -DMUJOCO_BUILD_TESTS=OFF \
    -DMUJOCO_TEST_PYTHON_UTIL=OFF \
    -DMUJOCO_WITH_USD=OFF \
    -DMUJOCO_USE_FILAMENT=${build_filament} \
    -DMUJOCO_BUILD_STUDIO=${build_studio} \
    -DMUJOCO_USE_FILAMENT_VULKAN=${build_vulkan} \
    -DFILAMENT_SUPPORTS_VULKAN=${build_vulkan} \
    -DFILAMENT_SKIP_SAMPLES=ON \
    -DCMAKE_INSTALL_PREFIX=${USER_INSTALL_DIR} \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_CXX_FLAGS=\"-Wno-error=deprecated-declarations\" \
    -DFILAMENT_SHORTEN_MSVC_COMPILATION=OFF \
    ${CCACHE_ARGS} \
    ${CMAKE_ARGS}

# -----------------------------------------------------------------------

# Build -----------------------------------------------------------------

echo "Building ..."

cmake --build build --config="${build_type}" --parallel ${njobs}

echo "Copy compile_commands.json to the root of the project"
cp build/compile_commands.json .

# -----------------------------------------------------------------------

# Install ---------------------------------------------------------------

echo "Installing to target dir ..."

source build_common.sh

install_studio_platform ${ROOT_DIR}/build ${USER_INSTALL_DIR}

# -----------------------------------------------------------------------

# Python bindings -------------------------------------------------------

echo "Make source distribution"

bash ${ROOT_DIR}/python/make_sdist_macos.sh

echo "Build python wheel"

export CCACHE_BASEDIR="${ROOT_DIR}/build"
export CCACHE_SLOPPINESS="time_macros,include_file_mtime,include_file_ctime,pch_defines,locale"
export MUJOCO_PATH="${USER_INSTALL_DIR}"
export MUJOCO_PLUGIN_PATH="${USER_INSTALL_DIR}/mujoco_plugin"
export MUJOCO_CMAKE_ARGS="-DCMAKE_INTERPROCEDURAL_OPTIMIZATION:BOOL=OFF ${CCACHE_ARGS} ${CMAKE_ARGS}"

uv build -v --wheel --force-pep517 ${ROOT_DIR}/python/dist/mujoco-*.tar.gz --out-dir ${ROOT_DIR}/python/dist

# -----------------------------------------------------------------------

# Clean install dir afterwards, to avoid being used as default search path
# rm -rf ${USER_INSTALL_DIR}

