###########################################
#  Ubuntu 20.04 as the base image 
###########################################
FROM ubuntu:20.04


###########################################
#  Build Args
###########################################
# Empty

###########################################
#  Labels for metadata and other configs
###########################################

LABEL maintainer="ArthurRL"
LABEL version="1.0.0"
LABEL description="This image builds Qt from source with support for X11, Dear ImGui, Vulkan, CUDA, and Qt Creator."
LABEL python_script="monitor.py"
LABEL base_image="ubuntu:20.04"

# Set non-interactive mode for apt-get installs
ENV DEBIAN_FRONTEND=noninteractive


#######################################
#  Timezone
#######################################
ENV TZ=America/Sao_Paulo
RUN apt-get update && apt-get -y upgrade && \
    apt-get install -y tzdata && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    rm -rf /var/lib/apt/lists/*


#######################################
#  Install Python and psutil
#######################################
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-dev python3-pip && \
    pip3 install psutil && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


##########################################
#  Install basic dependencies with apt
##########################################
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    wget \
    unzip \
    dkms \
    git \
    make \
    gdb \
    flex \
    bison \
    texinfo \
    pkg-config \
    gnupg \
    locales \
    lsb-release \
    ca-certificates \
    software-properties-common \
    gnupg \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    lldb \
    libdw-dev \
    libffi-dev \
    libxml2 \
    zlib1g-dev \
    libsqlite3-dev \
    libpqxx-dev \
    libssl-dev \
    libsecret-1-dev \
    libgcrypt20-dev \
    xz-utils \
    libxcb-cursor-dev \
    libx11-xcb1 \
    libx11-dev \
    libxi6 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libxext-dev \
    libxrandr-dev \
    libxrender-dev \
    libxcb1-dev \
    libxcb-glx0-dev \
    libxcb-keysyms1-dev \
    libxcb-image0-dev \
    libxcb-shm0-dev \
    libxcb-icccm4-dev \
    libxcb-sync0-dev \
    libxcb-xfixes0-dev \
    libxcb-shape0-dev \
    libxcb-randr0-dev \
    libxcb-render-util0-dev \
    libxcb-xinerama0-dev \
    libxi-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxkbcommon-x11-0 \
    libfontconfig1-dev \
    libfreetype6-dev \
    libglvnd-dev \
    libgl1-mesa-dev \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    libsm6 \
    libice6 \
    libpci-dev \
    libpulse-dev \
    libudev-dev \
    libxtst-dev \
    mesa-common-dev \
    mesa-utils \
    libjsoncpp-dev \
    libblas-dev \
    liblapack-dev \
    libopus-dev \
    libminizip-dev \
    libavutil-dev \
    libavformat-dev \
    libavcodec-dev \
    libevent-dev \
    libasound2-dev \
    libcpprest-dev \
    alsa-base \
    alsa-utils \
    pulseaudio \
    libvulkan1 vulkan-tools vulkan-utils mesa-vulkan-drivers \
    # libvulkan-dev vulkan-validationlayers \
    libglvnd0 \
    libglu1-mesa-dev \
    x11-xserver-utils \
    libwayland-dev wayland-protocols \
    xorg-dev \
    xterm \
    vim \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get -y upgrade \
    && apt-get autoremove


###################################
#  Locale and Language
###################################
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8


############################################
#  Global installation ENV
############################################
ENV LIBRARY_PATH="/usr/local"
ENV PATH="${LIBRARY_PATH}/bin:${PATH}"


###################################
# C++ configs
###################################
ENV GCC_VERSION="14.2.0"

RUN wget -q "https://github.com/gcc-mirror/gcc/archive/refs/tags/releases/gcc-${GCC_VERSION}.tar.gz" -O /tmp/gcc.tar.gz && \
    tar -xzf /tmp/gcc.tar.gz -C /tmp/ && \
    rm -f /tmp/gcc.tar.gz

# Create a separate build directory and compile GCC
RUN mkdir -p /tmp/gcc-build && cd /tmp/gcc-build && \
    /tmp/gcc-releases-gcc-${GCC_VERSION}/configure \
        --prefix="${LIBRARY_PATH}/gcc-${GCC_VERSION}" \
        --enable-languages="c,c++" \
        --disable-multilib && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    rm -rf /tmp/gcc-releases-gcc-${GCC_VERSION} /tmp/gcc-build

ENV CC="gcc"
ENV CXX="g++"


###################################
#  Install LLVM and Clang
###################################
ENV LLVM_VERSION="18"
RUN wget -q "https://apt.llvm.org/llvm.sh" -O /tmp/llvm.sh && \
    chmod +x /tmp/llvm.sh && \
    /tmp/llvm.sh ${LLVM_VERSION} && \
    rm /tmp/llvm.sh

RUN apt-get install llvm-18-dev libclang-18-dev clang-18 -y --no-install-recommends && \ 
    apt-get clean && rm -rf /var/lib/apt/lists/*


############################################
#  Installing Ninja (newer version)
############################################
ENV NINJA_VERSION="1.12.1"
RUN wget -q "https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux.zip" -O /tmp/ninja-linux.zip && \
    unzip /tmp/ninja-linux.zip -d /tmp/ && \
    rm -rf /tmp/ninja-linux.zip

RUN mv /tmp/ninja ${LIBRARY_PATH}/bin


############################################
#  Installing CMake (newer version)
############################################
ENV CMAKE_VERSION="3.31.6"
RUN wget "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz" -O /tmp/cmake-${CMAKE_VERSION}.tar.gz && \
    tar -xzvf /tmp/cmake-${CMAKE_VERSION}.tar.gz -C /tmp/ && \
    rm -rf /tmp/cmake-${CMAKE_VERSION}.tar.gz

RUN mkdir /tmp/cmake-${CMAKE_VERSION}/build && \
    cd /tmp/cmake-${CMAKE_VERSION}/build && \
    ../bootstrap && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    rm -rf /tmp/cmake-${CMAKE_VERSION}


###################################
# Set up all Libraries
###################################

# Set up Vulkan SDK
ENV VULKAN_SDK_VERSION="1.4.304.1"
RUN mkdir -p ${LIBRARY_PATH}/VulkanSDK && \
    wget -qO - "https://sdk.lunarg.com/sdk/download/${VULKAN_SDK_VERSION}/linux/vulkansdk-linux-x86_64-${VULKAN_SDK_VERSION}.tar.xz" | \
    tar -xJf - -C ${LIBRARY_PATH}/VulkanSDK

# Download and install GLFW from source
ENV GLFW_VERSION="3.4"
RUN wget "https://github.com/glfw/glfw/archive/refs/tags/${GLFW_VERSION}.tar.gz" -O /tmp/glfw-${GLFW_VERSION}.tar.gz && \
    tar -xzf /tmp/glfw-${GLFW_VERSION}.tar.gz -C /tmp/ && \
    rm -rf /tmp/glfw-${GLFW_VERSION}.tar.gz

RUN cmake -S /tmp/glfw-${GLFW_VERSION} -B /tmp/glfw-${GLFW_VERSION}/build -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} && \
    cmake --build /tmp/glfw-${GLFW_VERSION}/build --target install && \
    rm -rf /tmp/glfw-${GLFW_VERSION} /tmp/glfw-${GLFW_VERSION}.tar.gz

# Download and install GLAD-generated files (OpenGL)
RUN pip3 install --upgrade "git+https://github.com/dav1dde/glad.git#egg=glad" && \
    python3 -m glad --api="gl:core=4.6" --out-path=/tmp/glad

RUN mkdir -p ${LIBRARY_PATH}/include/glad && \
    mkdir -p ${LIBRARY_PATH}/src/glad && \
    mv /tmp/glad/include/* ${LIBRARY_PATH}/include/glad/ && \
    mv /tmp/glad/src/* ${LIBRARY_PATH}/src/glad/ && \
    rm -rf /tmp/glad

ENV DEARIMGUI_VERSION="1.91.8"
RUN wget "https://github.com/ocornut/imgui/archive/refs/tags/v${DEARIMGUI_VERSION}.tar.gz" -O /tmp/imgui-${DEARIMGUI_VERSION}.tar.gz && \
    tar -xzf /tmp/imgui-${DEARIMGUI_VERSION}.tar.gz -C /tmp/ && \
    rm /tmp/imgui-${DEARIMGUI_VERSION}.tar.gz

RUN mkdir -p ${LIBRARY_PATH}/include/imgui && \
    mv /tmp/imgui-${DEARIMGUI_VERSION}/* ${LIBRARY_PATH}/include/imgui/ && \
    rm -rf /tmp/imgui-${DEARIMGUI_VERSION}

# Download and install PLOG (header-only library)
ENV PLOG_VERSION="1.1.10"
RUN wget "https://github.com/SergiusTheBest/plog/archive/refs/tags/${PLOG_VERSION}.tar.gz" -O /tmp/plog-${PLOG_VERSION}.tar.gz && \
    tar -xzf /tmp/plog-${PLOG_VERSION}.tar.gz -C /tmp/ && \
    rm /tmp/plog-${PLOG_VERSION}.tar.gz

RUN mv /tmp/plog-${PLOG_VERSION}/include/* ${LIBRARY_PATH}/include/ && \
    rm -rf /tmp/plog-${PLOG_VERSION}

# Download and install GLM (header-only library)
ENV GLM_VERSION="1.0.1"
RUN wget "https://github.com/g-truc/glm/archive/refs/tags/${GLM_VERSION}.tar.gz" -O /tmp/glm-${GLM_VERSION}.tar.gz && \
    tar -xzf /tmp/glm-${GLM_VERSION}.tar.gz -C /tmp/ && \
    rm /tmp/glm-${GLM_VERSION}.tar.gz

RUN mv /tmp/glm-${GLM_VERSION}/glm ${LIBRARY_PATH}/include && \
    rm -rf /tmp/glm-${GLM_VERSION}

# Download NLOHMANN JSON lib (header-only library)
ENV NLOHMANN_JSON="3.11.3"
RUN wget "https://github.com/nlohmann/json/releases/download/v${NLOHMANN_JSON}/json.tar.xz" -O /tmp/json.tar.xz && \
    tar -xf /tmp/json.tar.xz -C /tmp/ && \
    rm /tmp/json.tar.xz

RUN mv /tmp/json/include/* ${LIBRARY_PATH}/include/ && \
    rm -rf /tmp/json

# Download C3C compiler
ENV C3C_VERSION="0.6.7"
RUN wget -q "https://github.com/c3lang/c3c/releases/download/v${C3C_VERSION}/c3-linux.tar.gz" -O /tmp/c3-linux.tar.gz && \
    tar -xzf /tmp/c3-linux.tar.gz -C /tmp/ && \
    rm /tmp/c3-linux.tar.gz

RUN mv /tmp/c3/lib/* ${LIBRARY_PATH}/lib && \
    mv /tmp/c3/c3c ${LIBRARY_PATH}/bin && \
    rm -rf /tmp/c3

# Build SQLITE lib from source
ENV SQLITECPP_VERSION="3.3.2"
RUN wget -q "https://github.com/SRombauts/SQLiteCpp/archive/refs/tags/${SQLITECPP_VERSION}.tar.gz" -O /tmp/SQLiteCpp-${SQLITECPP_VERSION}.tar.gz && \
    tar -xzf /tmp/SQLiteCpp-${SQLITECPP_VERSION}.tar.gz -C /tmp/ && \
    rm -rf /tmp/SQLiteCpp-${SQLITECPP_VERSION}.tar.gz

RUN cmake -S /tmp/SQLiteCpp-${SQLITECPP_VERSION} -B /tmp/SQLiteCpp-${SQLITECPP_VERSION}/build -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} && \
    cmake --build /tmp/SQLiteCpp-${SQLITECPP_VERSION}/build --target install && \
    rm -rf /tmp/SQLiteCpp-${SQLITECPP_VERSION}

# Raylib
ENV RAYLIB_VERSION="5.5"
RUN wget "https://github.com/raysan5/raylib/releases/download/${RAYLIB_VERSION}/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz" -O /tmp/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz && \
    tar -xzf /tmp/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz -C /tmp/ && \
    rm -rf /tmp/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz

RUN cp -r /tmp/raylib-${RAYLIB_VERSION}_linux_amd64/lib/* ${LIBRARY_PATH}/lib && \
    mkdir -p ${LIBRARY_PATH}/include/raylib && \
    cp -r /tmp/raylib-${RAYLIB_VERSION}_linux_amd64/include/* ${LIBRARY_PATH}/include/raylib && \
    rm -rf /tmp/raylib-${RAYLIB_VERSION}_linux_amd64


###################################
# Building Qt
###################################
ENV LLVM_INSTALL_DIR="/usr/lib/llvm-${LLVM_VERSION}"
ENV CMAKE_PREFIX_PATH="${LLVM_INSTALL_DIR}"

ENV QT="6.8.2"
ENV QT_DIR="/opt/Qt/${QT}"

# Install Qt manually using the specified version
RUN wget "https://download.qt.io/official_releases/qt/6.8/${QT}/single/qt-everywhere-src-${QT}.tar.xz" -O /tmp/qt-everywhere-src-${QT}.tar.xz && \
    tar -xJf /tmp/qt-everywhere-src-${QT}.tar.xz -C /tmp/ && \
    rm -rf /tmp/qt-everywhere-src-${QT}.tar.xz

RUN mkdir -p /tmp/qt-everywhere-src-${QT}/build && \
    cd /tmp/qt-everywhere-src-${QT}/build && \
    /tmp/qt-everywhere-src-${QT}/configure -prefix ${QT_DIR} -release -opensource -confirm-license -nomake tests -nomake examples -skip qtopcua && \
    cmake --build . --parallel $(nproc) && \
    cmake --install . && \
    cd / && \
    rm -rf /tmp/qt-everywhere-src-${QT}


###################################
# Building QtCreator
###################################
# Set GCC-14.2 as default compiler
RUN update-alternatives --install /usr/bin/gcc gcc ${LIBRARY_PATH}/gcc-${GCC_VERSION}/bin/gcc 100 && \
    update-alternatives --install /usr/bin/g++ g++ ${LIBRARY_PATH}/gcc-${GCC_VERSION}/bin/g++ 100 && \
    update-alternatives --set gcc ${LIBRARY_PATH}/gcc-${GCC_VERSION}/bin/gcc && \
    update-alternatives --set g++ ${LIBRARY_PATH}/gcc-${GCC_VERSION}/bin/g++ 

ENV CMAKE_PREFIX_PATH="${QT_DIR}/gcc_64:${QT_DIR}/lib:${QT_DIR}/lib/cmake:${QT_DIR}/lib/cmake/Qt6:${CMAKE_PREFIX_PATH}"

# Download Qt Creator source and build using CMake and Ninja
ENV QTCREATOR_VERSION="15.0.1"
ENV QTCREATOR="/opt/QtCreator"

RUN wget "https://download.qt.io/official_releases/qtcreator/15.0/${QTCREATOR_VERSION}/qt-creator-opensource-src-${QTCREATOR_VERSION}.tar.xz" -O /tmp/qt-creator-opensource-src-${QTCREATOR_VERSION}.tar.xz && \
    tar -xJf /tmp/qt-creator-opensource-src-${QTCREATOR_VERSION}.tar.xz -C /tmp/ && \
    rm -rf /tmp/qt-creator-opensource-src-${QTCREATOR_VERSION}.tar.xz

RUN cmake -S /tmp/qt-creator-opensource-src-${QTCREATOR_VERSION} -B /tmp/qt-creator-opensource-src-${QTCREATOR_VERSION}/build -DCMAKE_INSTALL_PREFIX=${QTCREATOR} \
        -DCMAKE_INSTALL_PREFIX=${QTCREATOR} -DCMAKE_BUILD_TYPE=Debug -G Ninja \
        -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}" && \
    cmake --build /tmp/qt-creator-opensource-src-${QTCREATOR_VERSION}/build --parallel $(nproc) --verbose --target install && \
    rm -rf /tmp/qt-creator-opensource-src-${QTCREATOR_VERSION}


############################################
#  CUDA drivers and toolkit installation
############################################
ENV CUDA_VERSION="12.8.0"
RUN wget "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin" && \
    mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600 && \
    wget "https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/cuda-repo-ubuntu2004-12-8-local_${CUDA_VERSION}-570.86.10-1_amd64.deb"

RUN dpkg -i cuda-repo-ubuntu2004-12-8-local_${CUDA_VERSION}-570.86.10-1_amd64.deb && \
    cp /var/cuda-repo-ubuntu2004-12-8-local/cuda-*-keyring.gpg /usr/share/keyrings/ && \
    apt-get update && apt-get -y install cuda-toolkit-12-8 cuda-drivers && \
    rm cuda-repo-ubuntu2004-12-8-local_${CUDA_VERSION}-570.86.10-1_amd64.deb /etc/apt/sources.list.d/cuda-ubuntu2004-12-8-local.list && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cuda-repo-ubuntu2004-12-8-local


###################################
# Important environment variables
###################################
ENV VULKAN_SDK="${LIBRARY_PATH}/VulkanSDK/${VULKAN_SDK_VERSION}/x86_64"
ENV VK_ICD_FILENAMES="${VULKAN_SDK}/etc/vulkan/icd.d:/usr/share/vulkan/icd.d"
ENV PATH="${LIBRARY_PATH}/bin:${PATH}:${LIBRARY_PATH}:${LIBRARY_PATH}/include:${VULKAN_SDK}/bin:${QTCREATOR}/bin:${QT_DIR}/gcc_64/bin:${LLVM_INSTALL_DIR}/bin:${PATH}"
ENV QT_QPA_PLATFORM_PLUGIN_PATH="${QT_DIR}/gcc_64/plugins/platforms"
ENV LD_LIBRARY_PATH="${QTCREATOR}/lib:${QT_DIR}/gcc_64/lib:${QT_DIR}/lib:${VULKAN_SDK}/lib:${LLVM_INSTALL_DIR}/lib"
ENV PKG_CONFIG_PATH="${QT_DIR}/gcc_64/lib/pkgconfig"

# Copy Python script
RUN mkdir -p /app
COPY ./monitor.py /app/monitor.py

# Default shell for interactive debugging (optional)
SHELL ["/bin/bash", "-c"]

# Run the Python script
ENTRYPOINT ["python3", "-u", "/app/monitor.py"]
