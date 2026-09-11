#!/usr/bin/env bash

set -e

build_type="Release"

echo "Going back to the root of the project"
ROOT_DIR="$(pwd)"

cd ${ROOT_DIR}

if [ ! -d "${ROOT_DIR}/install" ]; then
    mkdir install
fi

CCACHE_ARGS=""
if command -v ccache >/dev/null 2>&1; then
    CCACHE_ARGS="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
fi

SHOW_HELP=false
build_filament=OFF
build_studio=OFF
build_simulate=ON
fresh=false
py_version="py310"
njobs=4

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) SHOW_HELP=true; shift ;;
        --debug) build_type="Debug"; shift ;;
        --filament) build_filament=ON; shift ;;
        --studio) build_studio=ON; shift ;;
        --fresh) fresh=true; shift ;;
        --py-version) py_version="$2"; shift 2 ;;
        --njobs) njobs="$2"; shift 2 ;;
        *) echo "Unkown option: $1"; exit 1 ;;
    esac
done

[ "$fresh" == "true" ] && FRESH_CMD="--fresh" || FRESH_CMD=""

if [[ "${build_filament}" == "ON" ]]; then
    export CC=/usr/bin/clang
    export CXX=/usr/bin/clang++
    build_simulate=OFF
    build_studio=ON
fi

py_bin="/opt/python/cp310-cp310/bin/python"
case $py_version in
    py310) py_bin="/opt/python/cp310-cp310/bin/python" ;;
    py311) py_bin="/opt/python/cp311-cp311/bin/python" ;;
    py312) py_bin="/opt/python/cp312-cp312/bin/python" ;;
    py313) py_bin="/opt/python/cp313-cp313/bin/python" ;;
    py314) py_bin="/opt/python/cp314-cp314/bin/python" ;;
esac

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
    -DFILAMENT_SUPPORTS_VULKAN=ON \
    -DFILAMENT_SKIP_SAMPLES=ON \
    -DCMAKE_INSTALL_PREFIX=install \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_CXX_FLAGS=\"-Wno-error=deprecated-declarations\" \
    -DFILAMENT_SHORTEN_MSVC_COMPILATION=OFF \
    -DCMAKE_INSTALL_LIBDIR=lib \
    ${CCACHE_ARGS} \
    ${CMAKE_ARGS}

echo "Building ..."

cmake --build build --config="${build_type}" --parallel ${njobs}

echo "Installing to target dir ..."

cmake --install build

echo "Copy plugins to install directory"

mkdir -p install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/lib*.a ${ROOT_DIR}/install/lib
cp ${ROOT_DIR}/build/lib/libactuator.* ${ROOT_DIR}/install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libelasticity.* ${ROOT_DIR}/install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libsensor.* ${ROOT_DIR}/install/mujoco_plugin
cp ${ROOT_DIR}/build/lib/libsdf_plugin.* ${ROOT_DIR}/install/mujoco_plugin

echo "Make source distribution"

bash ${ROOT_DIR}/python/make_sdist_manylinux.sh --py-version $py_version

echo "Build python wheel"

export CCACHE_BASEDIR="${ROOT_DIR}/build"
export CCACHE_SLOPPINESS="time_macros,include_file_mtime,include_file_ctime,pch_defines,locale"
export MUJOCO_PATH="${ROOT_DIR}/install"
export MUJOCO_PLUGIN_PATH="${ROOT_DIR}/install/mujoco_plugin"
export MUJOCO_CMAKE_ARGS="-DCMAKE_INTERPROCEDURAL_OPTIMIZATION:BOOL=OFF ${CCACHE_ARGS} ${CMAKE_ARGS}"

${py_bin} -m pip wheel --use-pep517 -vvv ${ROOT_DIR}/python/dist/mujoco-*.tar.gz --wheel-dir ${ROOT_DIR}/python/dist

auditwheel repair --wheel-dir ${ROOT_DIR}/python/dist ${ROOT_DIR}/python/dist/mujoco-*.whl
