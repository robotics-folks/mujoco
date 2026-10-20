#!/bin/bash -xe
# Copyright 2022 DeepMind Technologies Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

py_version="py310"

while [[ $# -gt 0 ]]; do
    case $1 in
        --py-version) py_version="$2"; shift 2 ;;
        *) echo "Uknown option: $1"; exit 1 ;;
    esac
done

py_bin="/opt/python/cp310-cp310/bin/python"
case $py_version in
    py310) py_bin="/opt/python/cp310-cp310/bin/python" ;;
    py311) py_bin="/opt/python/cp311-cp311/bin/python" ;;
    py312) py_bin="/opt/python/cp312-cp312/bin/python" ;;
    py313) py_bin="/opt/python/cp313-cp313/bin/python" ;;
    py314) py_bin="/opt/python/cp314-cp314/bin/python" ;;
esac

# Figure out the path to this script (https://stackoverflow.com/a/246128).
package_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [[ "$(uname)" == CYGWIN* || "$(uname)" == MINGW* ]]; then
  package_dir="$(cygpath -m ${package_dir})"
  readonly tmp_dir="$(TMPDIR="${LOCALAPPDATA//\\/$'/'}/Temp" mktemp -d)"
else
  readonly tmp_dir="$(mktemp -d)"
fi

${py_bin} -m pip install --no-build-isolation \
    --index-url "${PYPI_INDEX_URL:-https://pypi.org/simple/}" \
    --upgrade --require-hashes \
    -r ${package_dir}/make_sdist_requirements.txt
pushd ${tmp_dir}
cp -r "${package_dir}"/* .

# Generate header files.
old_pythonpath="${PYTHONPATH}"
if [[ "$(uname)" == CYGWIN* || "$(uname)" == MINGW* ]]; then
  export PYTHONPATH="${old_pythonpath};${package_dir}/mujoco/python/.."
else
  export PYTHONPATH="${old_pythonpath}:${package_dir}/mujoco/python/.."
fi
${py_bin} "${package_dir}"/mujoco/codegen/generate_enum_traits.py > \
    mujoco/enum_traits.h
${py_bin} "${package_dir}"/mujoco/codegen/generate_function_traits.py > \
    mujoco/function_traits.h
${py_bin} "${package_dir}"/mujoco/codegen/generate_spec_bindings.py > \
    mujoco/specs.cc.inc
export PYTHONPATH="${old_pythonpath}"

# Copy over the LICENSE file.
cp "${package_dir}"/../LICENSE .

# Copy over CMake scripts.
mkdir -p mujoco/cmake
cp -r "${package_dir}"/../cmake/* mujoco/cmake

# Copy over Simulate source code.
cp -r "${package_dir}"/../simulate mujoco

${py_bin} -m build . --sdist
tar -tf dist/mujoco-*.tar.gz
popd

mkdir -p "${package_dir}"/dist
mv "${tmp_dir}"/dist/* "${package_dir}"/dist
