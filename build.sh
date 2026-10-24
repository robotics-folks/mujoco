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
build_samples=OFF
build_python=OFF
build_tests=OFF
install_dir=""
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
        --vulkan) build_vulkan=ON; shift ;;
        --studio) build_studio=ON; shift ;;
        --samples) build_samples=ON; shift ;;
        --python) build_python=ON; shift ;;
        --njobs) njobs="$2"; shift 2 ;;
        --tests) build_tests=ON; shift ;;
        --fresh) fresh=true; shift ;;
        --build-dir) build_dir="$2"; shift 2 ;;
        --install-dir) install_dir="$2"; shift 2 ;;
        # ------------------------------------------------
        *) echo "Unkown option: $1"; exit 1 ;;
    esac
done

if [ "$SHOW_HELP" == "true" ]; then
    cat <<EOF

Build MuJoCo engine and any bindings requested
Usage: ./build.sh [OPTIONS]

Options:
    -h, --help          Display this help message
    --configure         Configure the build process (cmake -S . -B build ...)
    --build             Builds the engine and any other targets (cmake -b build ...)
    --install           Install the engine artifacts into an install directory (cmake --install build)
    --debug             Configure the build in Debug mode
    --rel-with-deb      Configure the build in Release with Debug Info (RelWithDebInfo)
    --filament          Build with Filament support for the new renderer
    --vulkan            Build with Vulkan support for Filament
    --studio            Build Studio app (new version of Simulate)
    --samples           Build the samples that come with the engine
    --python            Build the Python bindings
    --njobs             Number of parallel jobs used for the build process
    --fresh             Use this to clean the Cmake cache and re-configure without rm -f the build dir
EOF
    exit 0
fi

if [[ "${build_filament}" == "ON" ]]; then
    build_simulate=OFF
fi

[[ -n $install_dir ]] && USER_INSTALL_DIR="${install_dir}" || USER_INSTALL_DIR="${ROOT_DIR}/install"

if [ ! -d "${USER_INSTALL_DIR}" ]; then
    mkdir -p $USER_INSTALL_DIR
fi

[ "$fresh" == "true" ] && FRESH_CMD="--fresh" || FRESH_CMD=""

if [ "$opt_should_configure" == "true" ]; then

    echo "Configuring ..."

    cmake $FRESH_CMD -S . -B build \
        -DCMAKE_BUILD_TYPE:STRING=${build_type} \
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION:BOOL=OFF \
        -DUSE_STATIC_LIBCXX=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DMUJOCO_BUILD_EXAMPLES=${build_samples} \
        -DMUJOCO_BUILD_DEV_EXAMPLES=${build_samples} \
        -DMUJOCO_BUILD_SIMULATE=${build_simulate} \
        -DMUJOCO_BUILD_TESTS=${build_tests} \
        -DMUJOCO_TEST_PYTHON_UTIL=OFF \
        -DMUJOCO_WITH_USD=OFF \
        -DMUJOCO_USE_FILAMENT=${build_filament} \
        -DMUJOCO_BUILD_STUDIO=${build_studio} \
        -DFILAMENT_SUPPORTS_VULKAN=${build_vulkan} \
        -DFILAMENT_SKIP_SAMPLES=ON \
        -DCMAKE_INSTALL_PREFIX=${USER_INSTALL_DIR} \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DCMAKE_CXX_FLAGS=\"-Wno-error=deprecated-declarations\" \
        -DFILAMENT_SHORTEN_MSVC_COMPILATION=OFF \
        ${CCACHE_ARGS} \
        ${CMAKE_ARGS}

fi

if [ "$opt_should_build" == "true" ]; then
    echo "Building ..."

    cmake --build build --config=${build_type} --parallel ${njobs}

    echo "Copy compile_commands.json to the root of the project"
    cp build/compile_commands.json .
fi

if [ "$opt_should_install" == "true" ]; then
    echo "Installing to target dir ..."

    source build_common.sh

    install_studio_platform ${ROOT_DIR}/build ${USER_INSTALL_DIR}
fi


if [[ "${build_python}" == "ON" ]]; then
    echo "Make source distribution"

    bash ${ROOT_DIR}/python/make_sdist.sh

    echo "Build python wheel"

    export CCACHE_BASEDIR="${ROOT_DIR}/build"
    export CCACHE_SLOPPINESS="time_macros,include_file_mtime,include_file_ctime,pch_defines,locale"
    export MUJOCO_PATH="${USER_INSTALL_DIR}"
    export MUJOCO_PLUGIN_PATH="${USER_INSTALL_DIR}/mujoco_plugin"
    export MUJOCO_CMAKE_ARGS="-DCMAKE_INTERPROCEDURAL_OPTIMIZATION:BOOL=OFF ${CCACHE_ARGS} ${CMAKE_ARGS}"

    uv build -v --wheel --force-pep517 ${ROOT_DIR}/python/dist/mujoco-*.tar.gz --out-dir ${ROOT_DIR}/python/dist
fi


