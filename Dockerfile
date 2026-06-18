###########################################
#  arthurrl/vulkan-dev:base as the base image 
###########################################
FROM arthurrl/vulkan-dev:base


############################################
# Pre-Configs
############################################
WORKDIR /workspace

RUN mkdir -p /home/developer
ENV HOME=/home/developer
WORKDIR /home/developer


###################################
# Unified System Dependencies
###################################
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Java & Utils (Required for Android Tools & SDKs)
    openjdk-21-jdk \
    # ONNX & Pybind
    libonnx-dev pybind11-dev \
    # Wayland (Required for libwma)
    wayland-protocols libwayland-dev \
    # Vulkan & Mesa
    libvulkan1 libvulkan-dev vulkan-tools mesa-vulkan-drivers && \
    apt-get clean && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*


###################################
# Set up all Libraries
###################################

# Download and install GLFW from source
ENV GLFW_VERSION="3.4"
RUN wget "https://github.com/glfw/glfw/archive/refs/tags/${GLFW_VERSION}.tar.gz" -O /tmp/glfw-${GLFW_VERSION}.tar.gz && \
    tar -xzf /tmp/glfw-${GLFW_VERSION}.tar.gz -C /tmp/ && \
    rm -rf /tmp/glfw-${GLFW_VERSION}.tar.gz && \
    # Build STATIC
    cmake -S /tmp/glfw-${GLFW_VERSION} -B /tmp/glfw-${GLFW_VERSION}/build_static \
        -DCMAKE_INSTALL_PREFIX=${LOCAL_PREFIX} -DBUILD_SHARED_LIBS=OFF && \
    cmake --build /tmp/glfw-${GLFW_VERSION}/build_static --target install --parallel $(( ($(nproc)+1)/2 )) && \
    rm -rf /tmp/glfw-${GLFW_VERSION}


# SDL from source
ENV SDL_VERSION="3.4.10"
RUN wget "https://github.com/libsdl-org/SDL/releases/download/release-${SDL_VERSION}/SDL3-${SDL_VERSION}.tar.gz" -O /tmp/SDL3-${SDL_VERSION}.tar.gz && \
    tar -xzf /tmp/SDL3-${SDL_VERSION}.tar.gz -C /tmp/ && \
    rm -rf /tmp/SDL3-${SDL_VERSION}.tar.gz && \
    # Build STATIC
    cmake -S /tmp/SDL3-${SDL_VERSION} -B /tmp/SDL3-${SDL_VERSION}/build_static \
        -DCMAKE_INSTALL_PREFIX=${LOCAL_PREFIX} \
        -DBUILD_SHARED_LIBS=OFF \
        -DSDL_ALSA=ON \
        -DSDL_OPENGL=ON \
        -DSDL_VULKAN=ON \
        -DSDL_X11_XSCRNSAVER=OFF && \
    cmake --build /tmp/SDL3-${SDL_VERSION}/build_static --target install --parallel $(( ($(nproc)+1)/2 )) && \
    rm -rf /tmp/SDL3-${SDL_VERSION}


# SDL2_ttf from source
ENV SDL_TTF_VERSION="3.2.2"
RUN wget "https://github.com/libsdl-org/SDL_ttf/releases/download/release-${SDL_TTF_VERSION}/SDL3_ttf-${SDL_TTF_VERSION}.tar.gz" -O /tmp/SDL3_ttf-${SDL_TTF_VERSION}.tar.gz && \
    tar -xzf /tmp/SDL3_ttf-${SDL_TTF_VERSION}.tar.gz -C /tmp/ && \
    rm -rf /tmp/SDL3_ttf-${SDL_TTF_VERSION}.tar.gz && \
    # Build STATIC
    cmake -S /tmp/SDL3_ttf-${SDL_TTF_VERSION} -B /tmp/SDL3_ttf-${SDL_TTF_VERSION}/build_static \
        -DCMAKE_INSTALL_PREFIX=${LOCAL_PREFIX} -DBUILD_SHARED_LIBS=OFF && \
    cmake --build /tmp/SDL3_ttf-${SDL_TTF_VERSION}/build_static --target install --parallel $(( ($(nproc)+1)/2 )) && \
    rm -rf /tmp/SDL3_ttf-${SDL_TTF_VERSION}

# Generate GLAD files (OpenGL 4.6)
RUN pip install --no-cache-dir glad && \
    python3 -m glad --generator=c --api="gl=4.6" --out-path=/tmp/glad

# Install GLAD headers/source
RUN mkdir -p ${LOCAL_PREFIX}/lib ${LOCAL_PREFIX}/include ${LOCAL_PREFIX}/src/glad && \
    mv /tmp/glad/include/glad ${LOCAL_PREFIX}/include/ && \
    mv /tmp/glad/src/* ${LOCAL_PREFIX}/src/glad/ && \
    rm -rf /tmp/glad

# Build static and shared GLAD libraries
RUN cd ${LOCAL_PREFIX}/src/glad && \
    gcc -fPIC -I${LOCAL_PREFIX}/include -c glad.c -o glad.o && \
    ar rcs ${LOCAL_PREFIX}/lib/libglad.a glad.o && \
    gcc -shared -fPIC glad.c -I${LOCAL_PREFIX}/include -o ${LOCAL_PREFIX}/lib/libglad.so.1.0.0 && \
    ln -sf libglad.so.1.0.0 ${LOCAL_PREFIX}/lib/libglad.so.1 && \
    ln -sf libglad.so.1 ${LOCAL_PREFIX}/lib/libglad.so && \
    rm glad.o

# DearImGui, GLM, Nlohmann JSON are header-only
ENV DEARIMGUI_VERSION="1.92.6"
RUN wget "https://github.com/ocornut/imgui/archive/refs/tags/v${DEARIMGUI_VERSION}.tar.gz" -O /tmp/imgui-${DEARIMGUI_VERSION}.tar.gz && \
    tar -xzf /tmp/imgui-${DEARIMGUI_VERSION}.tar.gz -C /tmp/ && \
    rm /tmp/imgui-${DEARIMGUI_VERSION}.tar.gz && \
    mkdir -p ${LOCAL_PREFIX}/include/imgui && \
    mv /tmp/imgui-${DEARIMGUI_VERSION}/* ${LOCAL_PREFIX}/include/imgui/ && \
    rm -rf /tmp/imgui-${DEARIMGUI_VERSION}

ENV GLM_VERSION="1.0.3"
RUN wget "https://github.com/g-truc/glm/archive/refs/tags/${GLM_VERSION}.tar.gz" -O /tmp/glm-${GLM_VERSION}.tar.gz && \
    tar -xzf /tmp/glm-${GLM_VERSION}.tar.gz -C /tmp/ && \
    rm /tmp/glm-${GLM_VERSION}.tar.gz && \
    mv /tmp/glm-${GLM_VERSION}/glm ${LOCAL_PREFIX}/include && \
    rm -rf /tmp/glm-${GLM_VERSION}

ENV NLOHMANN_JSON="3.12.0"
RUN wget "https://github.com/nlohmann/json/releases/download/v${NLOHMANN_JSON}/json.tar.xz" -O /tmp/json.tar.xz && \
    tar -xf /tmp/json.tar.xz -C /tmp/ && \
    rm /tmp/json.tar.xz && \
    mv /tmp/json/include/* ${LOCAL_PREFIX}/include/ && \
    rm -rf /tmp/json

# Build SQLITE lib from source
ENV SQLITECPP_VERSION="3.3.3"
RUN wget -q "https://github.com/SRombauts/SQLiteCpp/archive/refs/tags/${SQLITECPP_VERSION}.tar.gz" -O /tmp/SQLiteCpp-${SQLITECPP_VERSION}.tar.gz && \
    tar -xzf /tmp/SQLiteCpp-${SQLITECPP_VERSION}.tar.gz -C /tmp/ && \
    rm -rf /tmp/SQLiteCpp-${SQLITECPP_VERSION}.tar.gz && \
    # Build STATIC
    cmake -S /tmp/SQLiteCpp-${SQLITECPP_VERSION} -B /tmp/SQLiteCpp-${SQLITECPP_VERSION}/build_static \
        -DCMAKE_INSTALL_PREFIX=${LOCAL_PREFIX} -DBUILD_SHARED_LIBS=OFF \
        -DSQLITECPP_INTERNAL_SQLITE=ON && \
    cmake --build /tmp/SQLiteCpp-${SQLITECPP_VERSION}/build_static --target install --parallel $(( ($(nproc)+1)/2 )) && \
    rm -rf /tmp/SQLiteCpp-${SQLITECPP_VERSION}


# Raylib
ENV RAYLIB_VERSION="6.0"
RUN wget "https://github.com/raysan5/raylib/releases/download/${RAYLIB_VERSION}/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz" -O /tmp/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz && \
    tar -xzf /tmp/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz -C /tmp/ && \
    rm -rf /tmp/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz && \
    cp -r /tmp/raylib-${RAYLIB_VERSION}_linux_amd64/lib/* ${LOCAL_PREFIX}/lib && \
    cp -r /tmp/raylib-${RAYLIB_VERSION}_linux_amd64/include/* ${LOCAL_PREFIX}/include/ && \
    rm -rf /tmp/raylib-${RAYLIB_VERSION}_linux_amd64


# libink
RUN cd /tmp && \
    git clone "https://github.com/Arthu-RL/libink.git" && \
    cmake -S /tmp/libink -B /tmp/libink/build \ 
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${LOCAL_PREFIX} && \
    cmake --build /tmp/libink/build --target install --parallel $(( ($(nproc)+1)/2 )) && \
    rm -rf /tmp/libink


# libwma
RUN cd /tmp && \
    git clone "https://github.com/Arthu-RL/libwma.git" && \
    cmake -S /tmp/libwma -B /tmp/libwma/build \ 
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${LOCAL_PREFIX} && \
    cmake --build /tmp/libwma/build --target install --parallel $(($(nproc) / 2)) && \
    rm -rf /tmp/libwma


# JWT
ENV JWTCPP_VERSION="0.7.2"
RUN wget "https://github.com/Thalhammer/jwt-cpp/releases/download/v${JWTCPP_VERSION}/jwt-cpp-v${JWTCPP_VERSION}.tar.gz" -O /tmp/jwt-cpp-v${JWTCPP_VERSION}.tar.gz && \
    mkdir -p /tmp/jwt-cpp-v${JWTCPP_VERSION} && \
    tar -xvf /tmp/jwt-cpp-v${JWTCPP_VERSION}.tar.gz -C /tmp/jwt-cpp-v${JWTCPP_VERSION} --strip-components=1 && \
    rm -rf /tmp/jwt-cpp-v${JWTCPP_VERSION}.tar.gz && \
    cmake -S /tmp/jwt-cpp-v${JWTCPP_VERSION} -B /tmp/jwt-cpp-v${JWTCPP_VERSION}/build \
        -DCMAKE_INSTALL_PREFIX=${LOCAL_PREFIX} && \
    cmake --build /tmp/jwt-cpp-v${JWTCPP_VERSION}/build --target install --parallel $(( ($(nproc)+1)/2 )) && \
    rm -rf /tmp/jwt-cpp-v${JWTCPP_VERSION}


############################################
# ONNX RUNTIME (ORT)
############################################
ENV ORT_VERSION="1.26.0"

# Download the pre-compiled C++ library for Linux with GPU (CUDA 12.x) support
RUN wget "https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/onnxruntime-linux-x64-gpu-${ORT_VERSION}.tgz" -O /tmp/ort.tgz && \
    tar -xzf /tmp/ort.tgz -C /tmp/ && \
    cp -r /tmp/onnxruntime-linux-x64-gpu-${ORT_VERSION}/include/* ${LOCAL_PREFIX}/include/ && \
    cp -r /tmp/onnxruntime-linux-x64-gpu-${ORT_VERSION}/lib/* ${LOCAL_PREFIX}/lib/ && \
    # Cleanup
    rm -rf /tmp/ort.tgz /tmp/onnxruntime*


############################################
# STB libraries
############################################
RUN wget "https://raw.githubusercontent.com/nothings/stb/master/stb_image.h" -O ${LOCAL_PREFIX}/include/stb_image.h && \
    wget "https://raw.githubusercontent.com/nothings/stb/master/stb_image_write.h" -O ${LOCAL_PREFIX}/include/stb_image_write.h && \
    wget "https://raw.githubusercontent.com/nothings/stb/master/stb_image_resize2.h" -O ${LOCAL_PREFIX}/include/stb_image_resize2.h && \
    wget "https://raw.githubusercontent.com/nothings/stb/master/stb_vorbis.c" -O ${LOCAL_PREFIX}/include/stb_vorbis.c && \
    wget "https://raw.githubusercontent.com/nothings/stb/master/stb_include.h" -O ${LOCAL_PREFIX}/include/stb_include.h && \
    chmod 644 ${LOCAL_PREFIX}/include/stb_*


############################################
# Vulkan
############################################
# Set up Vulkan SDK
ENV VULKAN_SDK_VERSION="1.4.350.0"

RUN mkdir -p ${LOCAL_PREFIX}/VulkanSDK && \
    wget -qO /tmp/vulkansdk.tar.xz "https://sdk.lunarg.com/sdk/download/${VULKAN_SDK_VERSION}/linux/vulkansdk-linux-x86_64-${VULKAN_SDK_VERSION}.tar.xz" && \
    tar -xJf /tmp/vulkansdk.tar.xz -C ${LOCAL_PREFIX}/VulkanSDK && \
    rm -f /tmp/vulkansdk.tar.xz

ENV VMA_VERSION=3.4.0
RUN wget "https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator/archive/refs/tags/v${VMA_VERSION}.tar.gz" -O /tmp/vma.tar.gz && \
    tar -xzf /tmp/vma.tar.gz -C /tmp && \
    cp /tmp/VulkanMemoryAllocator-${VMA_VERSION}/include/* ${LOCAL_PREFIX}/include/ && \
    rm -rf /tmp/vma.tar.gz /tmp/VulkanMemoryAllocator-${VMA_VERSION}

ENV VULKAN_SDK="${LOCAL_PREFIX}/VulkanSDK/${VULKAN_SDK_VERSION}/x86_64"
ENV VK_ADD_LAYER_PATH="${VULKAN_SDK}/share/vulkan/explicit_layer.d"
ENV PKG_CONFIG_PATH="${VULKAN_SDK}/share/pkgconfig:${VULKAN_SDK}/lib/pkgconfig:${PKG_CONFIG_PATH}"


############################################
# Android SDK, NDK, and Gradle
############################################
ENV JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
ENV ANDROID_HOME="/opt/android-sdk"
ENV ANDROID_SDK_ROOT=${ANDROID_HOME}
ENV ANDROID_NDK_VERSION="27.1.12297006"
ENV ANDROID_NDK_HOME="${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}"

# Install Android SDK Command-line Tools and NDK
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    wget -q \
      https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
      -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d /tmp && \
    mv /tmp/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm -f /tmp/cmdline-tools.zip

ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${PATH}"
ENV PATH="${ANDROID_HOME}/platform-tools:${PATH}"

# Install SDK packages
RUN yes | sdkmanager --licenses >/dev/null && \
    sdkmanager \
        "platform-tools" \
        "platforms;android-35" \
        "build-tools;35.0.0" \
        "ndk;${ANDROID_NDK_VERSION}"

# Install Gradle
ENV GRADLE_VERSION="8.11.1"
ENV GRADLE_HOME="/opt/gradle/gradle-${GRADLE_VERSION}"
RUN wget -q "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -O /tmp/gradle.zip && \
    mkdir -p /opt/gradle && \
    unzip -q /tmp/gradle.zip -d /opt/gradle && \
    rm /tmp/gradle.zip

############################################
# Emscripten (WebAssembly)
############################################
ENV EMSDK="/opt/emsdk"
ENV EMSCRIPTEN_VERSION="6.0.0"
RUN git clone "https://github.com/emscripten-core/emsdk.git" ${EMSDK} && \
    cd ${EMSDK} && \
    git fetch --tags && \
    ./emsdk install ${EMSCRIPTEN_VERSION} && \
    ./emsdk activate ${EMSCRIPTEN_VERSION}


############################################
# ENV Setup
############################################
ENV PATH="${ANDROID_HOME}/platform-tools:${CMDLINE_TOOLS_ROOT}:${GRADLE_HOME}/bin:${EMSDK}:${EMSDK}/upstream/emscripten:${VULKAN_SDK}/bin:${PATH}"


############################################
# Verification
############################################
RUN sdkmanager --version && \
    adb version && \
    gradle --version

############################################
# Monitor
############################################
# Copy Python script
RUN mkdir -p /app
COPY ./monitor.py /app/monitor.py

# Default shell for interactive debugging (optional)
SHELL ["/bin/bash", "-c"]

# Run the Python script
ENTRYPOINT ["python3", "-u", "/app/monitor.py"]