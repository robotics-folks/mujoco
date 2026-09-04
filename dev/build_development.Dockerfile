FROM nvidia/cuda:13.3.0-cudnn-devel-ubuntu24.04

ARG DEBIAN_FRONTEND="noninteractive"
ENV TZ="America/Los_Angeles"

RUN :\
    && apt-get update \
    && apt-get install -y \
        build-essential pkg-config curl git wget cmake ccache unzip ninja-build python3-dev locales \
        man-db manpages manpages-dev manpages-posix manpages-posix-dev \
        libgl1-mesa-dev libwayland-dev libxinerama-dev libxkbcommon-dev libxrandr-dev libxi-dev libxcursor-dev liblodepng-dev \
        gdb fzf bat ripgrep xclip xsel fd-find jq zip btop nvtop ncdu \
    && rm -rf /var/lib/apt/lists/* \
    && :

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en

# Install Vulkan SDK
ARG VULKAN_SDK_VERSION="1.4.313"
RUN :\
    && echo "Install Vulkan-SDK ${VULKAN_SDK_VERSION}" \
    && wget -qO- https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - \
    && wget -qO /etc/apt/sources.list.d/lunarg-vulkan-${VULKAN_SDK_VERSION}-noble.list https://packages.lunarg.com/vulkan/${VULKAN_SDK_VERSION}/lunarg-vulkan-${VULKAN_SDK_VERSION}-noble.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends vulkan-sdk \
    && rm -rf /var/lib/apt/lists/* \
    && :

ENV PATH="/root/.local/bin/:$PATH"
ENV PYTHONBREAKPOINT="ipdb.set_trace"
ENV PATH="/opt/nvim-linux-x86_64/bin:$PATH"

# Use neovim from latest release, and configure lazyvim from a fork with setup for beaker
RUN :\
    && curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz \
    && tar -C /opt -xzf nvim-linux-x86_64.tar.gz \
    && mkdir -p ~/.config/nvim \
    && git clone -b beaker https://github.com/wpumacay/lazyvim-starter ~/.config/nvim \
    && :

# Required for some neovim LSPs (pyright, etc.)
RUN :\
    && curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash \
    && . "$HOME/.nvm/nvm.sh" \
    && nvm install 24 > /dev/null 2>&1 \
    && nvim --headless "+Lazy! sync" +qa > /dev/null 2>&1 \
    && :

ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh

RUN uv venv /root/.venv --python 3.11
ENV VIRTUAL_ENV=/root/.venv
ENV PATH="/root/.venv/bin:$PATH"

WORKDIR /mujoco

ENTRYPOINT [ "bash", "-l" ]
