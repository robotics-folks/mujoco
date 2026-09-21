#!/usr/bin/env bash

set +e

# Portable copy helpers. They preserve timestamps (cp -p): the Python
# extensions depend on these headers, so a copy that looked new would make
# every rebuild recompile everything.
_copy_headers() {  # $1=src dir, $2=dst dir — only *.h/*.inl, keep subdirs
    local s="${1%/}"
    (cd "${s}" && find . \( -name '*.h' -o -name '*.inl' \) -print0 |
        while IFS= read -r -d '' f; do
            mkdir -p "$2/${f%/*}" && cp -p "${f}" "$2/${f}"
        done)
}
_copy_tree() {  # $1=src dir, $2=dst dir — the whole subtree
    local s="${1%/}"
    mkdir -p "$2" && cp -rp "${s}/." "$2/"
}

# _copy_headers() {
#     local src_folder=$1
#     local dst_folder=$2
#     local files_to_cp=()
#     mapfile -d '' files_to_cp < <(find ${src_folder} \( -name '*.h' -o -name '*.inl' \) -print0)
#
#     for file_to_cp in "${files_to_cp[@]}"; do
#         mkdir -p "${dst_folder}/${file_to_cp%/*}" && cp -p "${file_to_cp}" "${dst_folder}/${file_to_cp}"
#     done
# }
#
# _copy_tree() {
#     local src_folder=$1
#     local dst_folder=$2
#     mkdir -p ${dst_folder} && cp -rp "${src_folder}/." "${dst_folder}/"
# }

install_studio_platform() {
    local build_dir=$1
    local install_dir=$2
    local plugin_ext plugin_dir

    case "$(uname -s)" in
        Darwin)
            plugin_ext="dylib";
            plugin_dir="${build_dir}/lib"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            plugin_ext="dll";
            plugin_dir="${build_dir}/bin"
            ;;
        *)
            plugin_ext="so";
            plugin_dir="${build_dir}/lib"
            ;;
    esac

    rm -rf ${install_dir}
    mkdir -p ${install_dir}

    if [ ! -d "${build_dir}" ]; then
        echo "[ERROR]: build directory ${build_dir} doesn't exist"
        return 1
    fi

    # 1. Standard install: libmujoco (runtime), headers + archives (dev), the export and models (Unspecified)
    for component in runtime dev Unspecified; do
        cmake --install ${build_dir} --prefix ${install_dir} --component ${component}
    done

    # 2. Engine plugins (setup.py packages them from MUJOCO_PLUGIN_PATH).
    mkdir -p ${install_dir}/mujoco_plugin
    for plugin in actuator elasticity sensor sdf_plugin; do
        find "${plugin_dir}" -name "*${plugin}.${plugin_ext}" \
            -exec cp {} "${install_dir}/mujoco_plugin/" \; 2>/dev/null || true
    done

    # 3. Static archives: mujoco_platform + every dependency archive; the Python
    #    build looks each one up by name with find_library().
    mkdir -p "${install_dir}/lib"
    find "${build_dir}" \( -name "*.a" -o -name "*.lib" \) -exec cp {} "${install_dir}/lib/" \;

    # 4. Source-tree headers for platform / filament-compat / render.
    _copy_headers src/experimental "${install_dir}/include/mujoco/experimental"
    _copy_headers src/render "${install_dir}/include/mujoco/render"

    # 5. Third-party headers.
    deps_dir="${build_dir}/_deps"
    # Dear ImGui.
    cp -p "${deps_dir}/dear_imgui-src/"im*.h "${install_dir}/include/"
    mkdir -p "${install_dir}/include/misc/cpp"
    cp -p "${deps_dir}/dear_imgui-src/misc/cpp/imgui_stdlib.h" "${install_dir}/include/misc/cpp/"
    mkdir -p "${install_dir}/include/backends"
    cp -p "${deps_dir}/dear_imgui-src/backends/"imgui_impl_{sdl2,opengl3}.h \
        "${install_dir}/include/backends/" 2>/dev/null || true
    # ImPlot.
    cp -p "${deps_dir}/implot-src/"implot*.h "${install_dir}/include/"
    # SDL2.
    mkdir -p "${install_dir}/include/SDL2"
    cp -p "${deps_dir}/sdl2-src/include/"*.h "${install_dir}/include/SDL2/"
    cp -fp "${deps_dir}/sdl2-build/include/"*.h "${install_dir}/include/SDL2/" 2>/dev/null || true
    cp -fp "${deps_dir}/sdl2-build/include-config-"*/*.h "${install_dir}/include/SDL2/" 2>/dev/null || true
    # Filament support libraries (math/, utils/, filament/, backend/, ...).
    for lib in math utils filament backend filabridge ibl; do
        [[ -d "${deps_dir}/filament-src/libs/${lib}/include/" ]] &&
            _copy_tree "${deps_dir}/filament-src/libs/${lib}/include" "${install_dir}/include"
    done
    _copy_tree "${deps_dir}/filament-src/filament/include" "${install_dir}/include"
    _copy_tree "${deps_dir}/filament-src/filament/backend/include" "${install_dir}/include"

    # 6. Studio runtime assets (fonts + Filament materials), staged by the
    #    mujoco_studio_assets target.
    if [[ ! -d "${build_dir}/bin/assets" ]]; then
        echo "ERROR: ${build_dir}/bin/assets is missing; build the mujoco_studio_assets target first" >&2
        return 1
    fi
    mkdir -p "${install_dir}/assets"
    cp -rp "${build_dir}/bin/assets/." "${install_dir}/assets/"

    echo "Gathered Studio platform compile inputs at ${install_dir}"
}

