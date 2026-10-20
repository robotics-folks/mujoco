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

## Using the wheels

To install the wheels you would just have to use `pip` and point to the path where the wheel lives:

```bash
uv pip install python/dist/mujoco-3.7.1-cp311-cp311-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl
```

We cannot host it on `PyPI` or `TestPyPI` because it will require to have a different package name,
like `mujoco-filament` or similar, and that messes up some stuff when trying to install this wheel
while having the original MuJoCo wheels from PyPI, making the installation fails sometimes.

## MolmoSpaces assets

If you want to try out the `MolmoSpaces` assets, you can download them like this:

```bash
molmospaces-download --type mjcf --mode batch \
    --batch.objects thor \
    --batch.robots franka_droid g1 i2rt_yam \
    --batch.scenes ithor procthor-10k-val
```
