#!/usr/bin/env bash

set -e

echo "Going back to the root of the project"
ROOT_DIR="$(pwd)"

if [ ! -d "${ROOT_DIR}/install" ]; then
    mkdir install
fi

CCACHE_ARGS=""
if command -v ccache >/dev/null 2>&1; then
    CCACHE_ARGS="-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
fi

SHOW_HELP=false
build_type="Release"
build_filament=OFF
build_studio=OFF
build_simulate=ON
fresh=false
py_version="py310"
njobs=4
fresh=false

opt_should_configure=false
opt_should_build=false
opt_should_install=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) SHOW_HELP=true; shift ;;
        # Script usage options ---------------------------
        --configure) opt_should_configure=true; shift ;;
        --build) opt_should_build=true; shift ;;
        --install) opt_should_install=true; shift ;;
        --all) opt_should_configure=true; opt_should_build=true; opt_should_install=true; shift ;;
        # ------------------------------------------------
        # Build options ----------------------------------
        --debug) build_type="Debug"; shift ;;
        --rel-with-deb) build_type="RelWithDebInfo"; shift ;;
        --filament) build_filament=ON; shift ;;
        --studio) build_studio=ON; shift ;;
        --fresh) fresh=true; shift ;;
        --py-version) py_version="$2"; shift 2 ;;
        --njobs) njobs="$2"; shift 2 ;;
        # ------------------------------------------------
        *) echo "Unkown option: $1"; exit 1 ;;
    esac
done

[ "$fresh" == "true" ] && FRESH_CMD="--fresh" || FRESH_CMD=""

if [[ "${build_filament}" == "ON" ]]; then
    build_simulate=OFF
fi

py_bin="/opt/python/cp310-cp310/bin/python"
case $py_version in
    py310) py_bin="/opt/python/cp310-cp310/bin/python" ;;
    py311) py_bin="/opt/python/cp311-cp311/bin/python" ;;
    py312) py_bin="/opt/python/cp312-cp312/bin/python" ;;
    py313) py_bin="/opt/python/cp313-cp313/bin/python" ;;
    py314) py_bin="/opt/python/cp314-cp314/bin/python" ;;
esac

if [ "$opt_should_configure" == "true" ]; then
    echo "Configuring ..."

    cmake $FRESH_CMD -S . -B build \
        -DCMAKE_BUILD_TYPE:STRING=${build_type} \
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION:BOOL=OFF \
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
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DCMAKE_CXX_FLAGS=\"-Wno-error=deprecated-declarations\" \
        -DFILAMENT_SHORTEN_MSVC_COMPILATION=OFF \
        ${CCACHE_ARGS} \
        ${CMAKE_ARGS}
fi

if [ "$opt_should_build" == "true" ]; then
    echo "Building ..."

    cmake --build build --config="${build_type}" --parallel ${njobs}

    echo "Copy compile_commands.json to the root of the project"
    cp build/compile_commands.json .
fi

if [ "$opt_should_install" == "true" ]; then
    echo "Installing to target dir ..."

    source build_common.sh

    install_studio_platform ${ROOT_DIR}/build ${ROOT_DIR}/install
fi

echo "Make source distribution"

bash ${ROOT_DIR}/python/make_sdist_manylinux.sh --py-version $py_version

echo "Build python wheel"

export CCACHE_BASEDIR="${ROOT_DIR}/build"
export CCACHE_SLOPPINESS="time_macros,include_file_mtime,include_file_ctime,pch_defines,locale"
export MUJOCO_PATH="${ROOT_DIR}/install"
export MUJOCO_PLUGIN_PATH="${ROOT_DIR}/install/mujoco_plugin"
export MUJOCO_CMAKE_ARGS="-DCMAKE_INTERPROCEDURAL_OPTIMIZATION:BOOL=OFF ${CCACHE_ARGS} ${CMAKE_ARGS}"

${py_bin} -m pip wheel --use-pep517 -vvv ${ROOT_DIR}/python/dist/mujoco-*.tar.gz --wheel-dir ${ROOT_DIR}/python/dist

LD_LIBRARY_PATH="${ROOT_DIR}/install/lib:${LD_LIBRARY_PATH}" auditwheel repair --wheel-dir ${ROOT_DIR}/python/dist ${ROOT_DIR}/python/dist/mujoco-*.whl
