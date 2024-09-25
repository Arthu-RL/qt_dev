# Use Ubuntu 20.04 as the base image
FROM ubuntu:20.04

# Set non-interactive mode for apt-get installs
ENV DEBIAN_FRONTEND=noninteractive

# Labels
LABEL VERSION=1.0.0

# Install basic dependencies for building the driver, Vulkan support, and tools
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    wget \
    dkms \
    git \
    gnupg \
    software-properties-common \
    libclang-dev \
    ninja-build \
    libgl1-mesa-dev \
    libvulkan1 \
    libvulkan-dev \
    vulkan-tools \
    vulkan-utils \
    mesa-vulkan-drivers \
    vulkan-validationlayers \
    libglvnd0 \
    x11-xserver-utils \
    libwayland-dev \
    wayland-protocols \
    xorg-dev \
    libxkbcommon-dev \
    libxcb-xinerama0-dev \
    libxkbcommon-x11-0 \
    python3 python3-pip && \
    pip3 install psutil && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Build and install GLFW from source
RUN git clone https://github.com/glfw/glfw.git /tmp/glfw && \
    cd /tmp/glfw && \
    cmake -Bbuild -H. && \
    cmake --build build --target install && \
    rm -rf /tmp/glfw

# CUDA drivers and toolkit installation
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin && \
    mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600 && \
    wget https://developer.download.nvidia.com/compute/cuda/12.6.1/local_installers/cuda-repo-ubuntu2004-12-6-local_12.6.1-560.35.03-1_amd64.deb && \
    dpkg -i cuda-repo-ubuntu2004-12-6-local_12.6.1-560.35.03-1_amd64.deb && \
    cp /var/cuda-repo-ubuntu2004-12-6-local/cuda-*-keyring.gpg /usr/share/keyrings/ && \
    apt-get update && apt-get -y install cuda-toolkit-12-6 cuda-drivers && \
    rm /etc/apt/sources.list.d/cuda-ubuntu2004-12-6-local.list && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cuda-repo-ubuntu2004-12-6-local

# Create the directory and install the Vulkan SDK
RUN mkdir -p /usr/local/VulkanSDK && \
    wget -qO - https://sdk.lunarg.com/sdk/download/1.3.290.0/linux/vulkansdk-linux-x86_64-1.3.290.0.tar.xz | tar -xJf - -C /usr/local/VulkanSDK

# Set Vulkan environment variables
ENV VULKAN_SDK=/usr/local/VulkanSDK/1.3.290.0/x86_64
ENV PATH=$VULKAN_SDK/bin:$PATH
ENV LD_LIBRARY_PATH=$VULKAN_SDK/lib:$LD_LIBRARY_PATH
ENV VK_ICD_FILENAMES=$VULKAN_SDK/etc/vulkan/icd.d:/usr/share/vulkan/icd.d

# Install Qt dependencies
RUN apt-get update && apt-get install -y \
    qtbase5-dev \
    qtwebengine5-dev \
    qt5-qmake \
    qtchooser \
    qttools5-dev-tools && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Add the LLVM repository for clang and llvm
RUN wget https://apt.llvm.org/llvm.sh && \
    chmod +x llvm.sh && ./llvm.sh 14 && \
    apt-get install -y libclang-14-dev llvm-14-dev && \
    rm llvm.sh && apt-get clean && rm -rf /var/lib/apt/lists/*

# Upgrade CMake to version 3.26.4 (or a newer version)
RUN apt-get -y purge --auto-remove cmake && \
    wget https://github.com/Kitware/CMake/releases/download/v3.26.4/cmake-3.26.4-linux-x86_64.sh && \
    chmod +x cmake-3.26.4-linux-x86_64.sh && \
    ./cmake-3.26.4-linux-x86_64.sh --skip-license --prefix=/usr/local && \
    rm cmake-3.26.4-linux-x86_64.sh

# Argument for Qt version
ARG QTVERSION=6.7.2

# Install Qt manually using the specified version
RUN wget https://download.qt.io/official_releases/qt/6.7/$QTVERSION/single/qt-everywhere-src-$QTVERSION.tar.xz -O /tmp/qt-everywhere-src-$QTVERSION.tar.xz && \
    cd /tmp && \
    tar -xJf qt-everywhere-src-$QTVERSION.tar.xz && \
    mkdir /tmp/qt-everywhere-src-$QTVERSION/build && \
    cd /tmp/qt-everywhere-src-$QTVERSION/build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=/opt/Qt/$QTVERSION && \
    cmake --build . --parallel $(nproc) && \
    cmake --install . && \
    rm -rf /tmp/qt-everywhere-src-$QTVERSION*

# Download Qt Creator source
RUN git clone https://code.qt.io/qt-creator/qt-creator.git /tmp/qt-creator && \
    cd /tmp/qt-creator && \
    git submodule update --init --recursive

# Set Qt6_DIR to the location where Qt6Config.cmake is installed
ENV Qt6_DIR=/opt/Qt/$QTVERSION/lib/cmake/Qt6
ENV CMAKE_PREFIX_PATH=/opt/Qt/$QTVERSION/gcc_64:$CMAKE_PREFIX_PATH

# Build Qt Creator using CMake and Ninja
RUN mkdir /tmp/qtcreator_build && \
    cd /tmp/qtcreator_build && \
    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="/opt/Qt/$QTVERSION/gcc_64" /tmp/qt-creator && \
    cmake --build . && \
    cmake --install . --prefix /opt/QtCreator

# Clean up Qt build
RUN rm -rf /tmp/qt-creator /tmp/qtcreator_build

# Set environment variables to ensure Qt Creator uses correct Qt and LLVM paths
ENV QTDIR=/opt/Qt/$QTVERSION/gcc_64
ENV PATH=/opt/QtCreator/bin:/opt/Qt/$QTVERSION/gcc_64/bin:/usr/lib/llvm-14/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/QtCreator/lib:/opt/Qt/$QTVERSION/gcc_64/lib:/usr/lib/llvm-14/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH=/opt/Qt/$QTVERSION/gcc_64/lib/pkgconfig:$PKG_CONFIG_PATH
ENV CMAKE_PREFIX_PATH=/opt/Qt/$QTVERSION/gcc_64;/usr/lib/llvm-14

# Copy Python script to the container (placing it in a common app directory)
COPY ./monitor.py /app/monitor.py

# Expose port for QtCreator's debugger (optional)
# EXPOSE 1234

# Run the Python script in interactive mode
CMD ["python3", "/app/monitor.py"]
