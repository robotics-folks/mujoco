# How to build with filament support

Currently we support only making wheels for Linux (haven't fully tested on MacOS, we're working
on that).

## Build MuJoCo

If you just want to try out building this fork from source (like, trying out the `studio` app), you
can use the `build.sh` helper script:

```bash
./build.sh \
    --filament \
    --vulkan \
    --studio \
    --njobs 5
```

The supported flags are the following: - `--filament`: whether or not to build with filament as the renderer of choice. - `--vulkan`: whether or not to use vulkan as rendering backend (for Linux). Metal support
for MacOS is not yet supported, only OpenGL is available for this platform. - `--studio`: whether or not to build the studio app (successor to the `simulate` app). - `--njobs`: number of threads to use for parallel build.

## Build Python wheels for Linux

To build manylinux wheels we can use the `build_manylinux.sh` helper script inside a docker container
built specifically for manylinux wheels. The steps are the following:

- Manylinux builder image

Build the docker image for making manylinux wheels using the base docker file
`build_manylinux.Dockerfile`.

```bash
# Run from the root of the repo
docker buildx build -t mujoco-ai2-manylinux:latest -f ai2/build_manylinux.Dockerfile . --platform linux/amd64
```

- Spin up the manylinux docker container

```bash
# Run the container
docker run -it --rm -v $PWD/python/dist/:/mujoco/python/dist/ mujoco-ai2-manylinux:latest
```

- Generate the Python wheels for your desired version of Python

```bash
# From within the container
./build_manylinux_wheel.sh --all --filament --studio --fresh --njobs 5 --py-version py311
```

- Using the wheel

To install the wheels you would just have to use `pip` and point to the path where the wheel lives:

```bash
uv pip install python/dist/mujoco-3.16.1-cp311-cp311-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl
```

## Build Python wheels for MacOS

To build macos wheels we can use the `build_macos_wheel` helper script directly from a macbook
or a mac studio. Just run the following (the script expects to have an activated virtual
environment managed by `uv`, so make sure you're using it instead of `conda` or `virtualenv`):

```bash
./build_macos_wheel.sh --filament --vulkan --studio --fresh --njobs 5
```

Notice that the wheel to be built corresponds to the python version being used by the activated
python `uv` environment, so just create a new virtual environment for each version of python
you want to build wheels for:

```bash
# For py311
uv venv .venv-311 --python 3.11
. .venv-311/bin/activate
./build_macos_wheel.sh --filament --vulkan --studio --fresh --njobs 5

# For py312
uv venv .venv-312 --python 3.12
. .venv-312/bin/activate
./build_macos_wheel.sh --filament --vulkan --studio --fresh --njobs 5
```

## MolmoSpaces assets

If you want to try out the `MolmoSpaces` assets, you can download them like this:

```bash
molmospaces-download --type mjcf --mode batch \
    --batch.objects thor \
    --batch.robots franka_droid g1 i2rt_yam \
    --batch.scenes ithor procthor-10k-val
```
