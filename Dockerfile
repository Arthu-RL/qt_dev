# Use Ubuntu 20.04 as the base image
FROM ubuntu:20.04

# Set non-interactive mode for apt-get installs
ENV DEBIAN_FRONTEND=noninteractive

# Labels
LABEL VERSION=1.0.0

# Install basic dependencies for building the driver and Vulkan support
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    wget \
    dkms \
    git \
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
    libxkbcommon-dev

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
    rm cuda-repo-ubuntu2004-12-6-local_12.6.1-560.35.03-1_amd64.deb && \
    cp /var/cuda-repo-ubuntu2004-12-6-local/cuda-*-keyring.gpg /usr/share/keyrings/ && \
    apt-get update && apt-get -y install cuda-toolkit-12-6 cuda-drivers

# Create the directory and install the Vulkan SDK
RUN mkdir -p /usr/local/VulkanSDK && \
    wget -qO - https://sdk.lunarg.com/sdk/download/1.3.290.0/linux/vulkansdk-linux-x86_64-1.3.290.0.tar.xz | tar -xJf - -C /usr/local/VulkanSDK

# Set Vulkan environment variables (using the versioned directory)
ENV VULKAN_SDK=/usr/local/VulkanSDK/1.3.290.0/x86_64
ENV PATH=$VULKAN_SDK/bin:$PATH
ENV LD_LIBRARY_PATH=$VULKAN_SDK/lib:$LD_LIBRARY_PATH
ENV VK_ICD_FILENAMES=$VULKAN_SDK/etc/vulkan/icd.d:/usr/share/vulkan/icd.d

# Install Qt 6.7.2 manually
RUN wget https://download.qt.io/official_releases/qt/6.7/6.7.2/single/qt-everywhere-src-6.7.2.tar.xz -O /tmp/qt-everywhere-src-6.7.2.tar.xz && \
    cd /tmp && \
    tar -xJf qt-everywhere-src-6.7.2.tar.xz && \
    cd qt-everywhere-src-6.7.2 && \
    ./configure -prefix /opt/Qt6.7.2 && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/qt-everywhere-src-6.7.2*

# Intalling python & pip
RUN apt-get update && apt-get install -y python3 python3-pip && \
    pip3 install psutil pynvml

# Clean up apt lists to reduce image size
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Python script to the container (placing it in a common app directory)
COPY ./monitor.py /app/monitor.py

# Expose port for QtCreator's debugger (optional)
EXPOSE 1234

# Run the Python script in interactive mode
CMD ["python3", "/app/monitor.py"]
