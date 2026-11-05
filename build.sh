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
build_version="4.0.0"

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
build_dev_samples=OFF
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
        --dev-samples) build_dev_samples=ON; shift ;;
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

[[ -n $install_dir ]] && USER_INSTALL_DIR="${install_dir}" || USER_INSTALL_DIR="${ROOT_DIR}/mujoco_install"

if [ ! -d "${USER_INSTALL_DIR}" ]; then
    mkdir -p $USER_INSTALL_DIR
fi

EXTERNAL_DEPS_DIR=${ROOT_DIR}/external_deps
if [ ! -d "${EXTERNAL_DEPS_DIR}" ]; then
    mkdir -p $EXTERNAL_DEPS_DIR
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
        -DMUJOCO_BUILD_DEV_EXAMPLES=${build_dev_samples} \
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

    if [[ "${build_filament}" == "ON" ]]; then
        source build_common.sh

        install_studio_platform ${ROOT_DIR}/build ${USER_INSTALL_DIR}
    else
        rm -rf ${USER_INSTALL_DIR}
        mkdir -p ${USER_INSTALL_DIR}

        cmake --install ${ROOT_DIR}/build --prefix ${USER_INSTALL_DIR}

        case "$(uname -s)" in
            Darwin) plugin_ext="dylib" ;;
            MINGW*|MSYS*|CYGWIN*) plugin_ext="dll" ;;
            *) plugin_ext="so" ;;
        esac

        mkdir -p ${USER_INSTALL_DIR}/mujoco_plugin
        for plugin in actuator elasticity sensor sdf_plugin; do
            find ${ROOT_DIR}/build -name "*${plugin}.${plugin_ext}" \
                -exec cp {} "${USER_INSTALL_DIR}/mujoco_plugin/" \; 2>/dev/null || true
        done
    fi
fi

# Helpers -----------------------------------------------------------------------------------------

# Populate ext_deps_args with -DFETCHCONTENT_SOURCE_DIR_<DEP>=<path> for each
# cached dependency in $2 (defaults to EXTERNAL_DEPS_DIR). When a target build
# directory ($1) is given, stage each cached dependency into $1/_deps/<dep>-src
# so targets and helper scripts that reference ${CMAKE_BINARY_DIR}/_deps/<dep>-src
# directly (e.g. Studio fonts, Filament WASM host imports,
# install_studio_platform) find the sources at their standard _deps/<dep>-src
# paths.
_setup_ext_deps_args() {
    local build_dir="${1:-}"
    local ext_deps_dir="${2:-${EXTERNAL_DEPS_DIR:-${ROOT_DIR:-/tmp}/external_deps}}"
    ext_deps_args=()
    if [[ ! -d "${ext_deps_dir}" ]]; then
        return 0
    fi
    ext_deps_dir="$(cd "${ext_deps_dir}" && pwd)"
    local target_deps_dir=""
    if [[ -n "${build_dir}" ]]; then
        mkdir -p "${build_dir}/_deps"
        target_deps_dir="$(cd "${build_dir}/_deps" && pwd)"
    fi
    for dep_path in "${ext_deps_dir}"/*; do
        if [[ -d "${dep_path}" ]]; then
            local dep_name
            dep_name="$(basename "${dep_path}")"
            if [[ "${dep_name}" == *-build || "${dep_name}" == *-subbuild ]]; then
                continue
            fi
            dep_name="${dep_name%-src}"
            if [[ "${dep_name}" == "mujoco" ]]; then
                continue
            fi
            local dep_upper
            dep_upper="$(echo "${dep_name}" | tr '[:lower:]' '[:upper:]')"
            local use_path="${dep_path}"
            if [[ -n "${target_deps_dir}" ]]; then
                local staged_dir="${target_deps_dir}/${dep_name}-src"
                if [[ ! -d "${staged_dir}" ]]; then
                    cp -al "${dep_path}" "${staged_dir}" 2>/dev/null || \
                        cp -RLp "${dep_path}" "${staged_dir}" || \
                        cp -rp "${dep_path}" "${staged_dir}"
                fi
                use_path="${staged_dir}"
            fi
            if command -v cygpath >/dev/null 2>&1; then
                use_path="$(cygpath -m "${use_path}")"
            fi
            echo "Using cached ${dep_name} from ${use_path}"
            ext_deps_args+=("-DFETCHCONTENT_SOURCE_DIR_${dep_upper}=${use_path}")
            # python/mujoco/CMakeLists.txt declares "eigen" instead of "Eigen3".
            if [[ "${dep_upper}" == "EIGEN3" ]]; then
                ext_deps_args+=("-DFETCHCONTENT_SOURCE_DIR_EIGEN=${use_path}")
            elif [[ "${dep_upper}" == "EIGEN" ]]; then
                ext_deps_args+=("-DFETCHCONTENT_SOURCE_DIR_EIGEN3=${use_path}")
            fi
        fi
    done
}

# Copy any newly fetched dependencies from $1/_deps/<dep>-src into
# EXTERNAL_DEPS_DIR so actions/cache can persist them across runs.
_populate_ext_deps_cache() {
    local build_dir="${1:-.}"
    local ext_deps_dir="${EXTERNAL_DEPS_DIR:-${ROOT_DIR:-/tmp}/external_deps}"
    for src in "${build_dir}/_deps"/*-src; do
        if [[ ! -d "${src}" ]]; then
            continue
        fi
        local dep_dir="${src##*/}"
        local dst_name="${dep_dir%-src}"
        if [[ "${dst_name}" == "mujoco" ]]; then
            continue
        fi
        if [[ "${dst_name}" == "eigen" ]]; then
            dst_name="eigen3"
        fi
        local dst="${ext_deps_dir}/${dst_name}"
        if [[ ! -d "${dst}" ]]; then
            echo "Populating external dependencies cache for ${dst_name}..."
            mkdir -p "${ext_deps_dir}"
            rm -rf "${src}/.git"
            cp -RLp "${src}" "${dst}" || cp -rp "${src}" "${dst}"
        fi
    done
}

# -------------------------------------------------------------------------------------------------

if [[ "${build_python}" == "ON" ]]; then
    echo "Make Python sdist ..."

    bash ${ROOT_DIR}/python/make_sdist.sh
    bash ${ROOT_DIR}/python/studio/make_sdist.sh
    bash ${ROOT_DIR}/python/mujoco_full/make_sdist.sh

    mv ${ROOT_DIR}/python/studio/dist/mujoco_studio-*.tar.gz ${ROOT_DIR}/python/dist/
    mv ${ROOT_DIR}/python/mujoco_full/dist/mujoco-*.tar.gz ${ROOT_DIR}/python/dist/

    echo "Build python wheel"

    if command -v cygpath >/dev/null 2>&1; then
        export CCACHE_BASEDIR="$(cygpath -m "${ROOT_DIR}")"
    else
        export CCACHE_BASEDIR="$(cd "${ROOT_DIR}" && pwd -P)"
    fi

    export CCACHE_NOHASHDIR=1
    export CCACHE_SLOPPINESS="time_macros,include_file_mtime,include_file_ctime,pch_defines,locale"

    py_deps_dir="${CCACHE_BASEDIR}/python_cmake_deps"
    rm -rf "${py_deps_dir}"
    mkdir -p "${py_deps_dir}/_deps"
    sdists=(mujoco_core-${build_version}.tar.gz mujoco-${build_version}.tar.gz)
    if [[ -f "${USER_INSTALL_DIR}/lib/libmujoco_studio_platform.a" || \
          -f "${USER_INSTALL_DIR}/lib/mujoco_studio_platform.lib" || \
          -f "${USER_INSTALL_DIR}/bin/Release/mujoco_studio_platform.lib" ]]; then
        sdists+=(mujoco_studio-${build_version}.tar.gz)
    fi

    export MUJOCO_PATH="${USER_INSTALL_DIR}"
    export MUJOCO_PLUGIN_PATH="${USER_INSTALL_DIR}/mujoco_plugin"
    export MUJOCO_CMAKE_ARGS="-DCMAKE_INTERPROCEDURAL_OPTIMIZATION:BOOL=OFF -DFETCHCONTENT_BASE_DIR=${py_deps_dir}/_deps ${CCACHE_ARGS} ${CMAKE_ARGS} ${ext_deps_args[*]}"

    (cd ${ROOT_DIR}/python/dist && echo "Changed to $(pwd)" && echo "Using dists: ${sdists[@]}" && python -m pip wheel -v --no-deps --no-build-isolation "${sdists[@]}")

    _populate_ext_deps_cache "${py_deps_dir}"
    rm -rf "${py_deps_dir}"

    echo "DONE building Python wheels :D"
fi
