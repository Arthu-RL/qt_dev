###########################################
#  arthurrl/vulkan-dev:base as the base image 
###########################################
FROM arthurrl/vulkan-dev:base


############################################
# Pre-Configs
############################################
WORKDIR /workspace


###########################################
#  Build Args
###########################################
# Empty


###################################
# Set up all Libraries
###################################

RUN apt-get update && \
    apt-get install -y --install-recommends \
    libonnx-dev pybind11-dev && \
    rm -rf /var/lib/apt/lists/*

# Set up Vulkan SDK
ENV VULKAN_SDK_VERSION="1.4.328.1"
RUN mkdir -p ${LIBRARY_PATH}/VulkanSDK && \
    wget -qO - "https://sdk.lunarg.com/sdk/download/${VULKAN_SDK_VERSION}/linux/vulkansdk-linux-x86_64-${VULKAN_SDK_VERSION}.tar.xz" | \
    tar -xJf - -C ${LIBRARY_PATH}/VulkanSDK
# vk env
ENV VULKAN_ROOT="${LIBRARY_PATH}/VulkanSDK/${VULKAN_SDK_VERSION}"
RUN chmod +x ${VULKAN_ROOT}/setup-env.sh && \
    echo "source ${VULKAN_ROOT}/setup-env.sh" >> ~/.bashrc

# Download and install GLFW from source
ENV GLFW_VERSION="3.4"
RUN wget "https://github.com/glfw/glfw/archive/refs/tags/${GLFW_VERSION}.tar.gz" -O /tmp/glfw-${GLFW_VERSION}.tar.gz && \
    tar -xzf /tmp/glfw-${GLFW_VERSION}.tar.gz -C /tmp/ && \
    rm -rf /tmp/glfw-${GLFW_VERSION}.tar.gz && \
    # Build SHARED
    # cmake -S /tmp/glfw-${GLFW_VERSION} -B /tmp/glfw-${GLFW_VERSION}/build_shared \
    #     -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} -DBUILD_SHARED_LIBS=ON && \
    # cmake --build /tmp/glfw-${GLFW_VERSION}/build_shared --target install --parallel $(nproc) && \
    # Build STATIC
    cmake -S /tmp/glfw-${GLFW_VERSION} -B /tmp/glfw-${GLFW_VERSION}/build_static \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} -DBUILD_SHARED_LIBS=OFF && \
    cmake --build /tmp/glfw-${GLFW_VERSION}/build_static --target install --parallel $(nproc) && \
    rm -rf /tmp/glfw-${GLFW_VERSION}


# SDL2 from source
RUN cd /tmp && \
    git clone "https://github.com/libsdl-org/SDL.git" -b SDL2 && \
    # Build SHARED
    # cmake -S /tmp/SDL -B /tmp/SDL/build_shared \
    #     -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} -DBUILD_SHARED_LIBS=ON \
    #     -DSDL_ALSA=ON -DSDL_OPENGL=ON -DSDL_VULKAN=ON && \
    # cmake --build /tmp/SDL/build_shared --target install --parallel $(nproc) && \
    # Build STATIC
    cmake -S /tmp/SDL -B /tmp/SDL/build_static \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} -DBUILD_SHARED_LIBS=OFF \
        -DSDL_ALSA=ON -DSDL_OPENGL=ON -DSDL_VULKAN=ON && \
    cmake --build /tmp/SDL/build_static --target install --parallel $(nproc) && \
    rm -rf /tmp/SDL


# SDL2_ttf from source
RUN cd /tmp && \
    git clone "https://github.com/libsdl-org/SDL_ttf.git" -b SDL2 && \
    # # Build SHARED
    # cmake -S /tmp/SDL_ttf -B /tmp/SDL_ttf/build_shared \
    #     -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} -DBUILD_SHARED_LIBS=ON && \
    # cmake --build /tmp/SDL_ttf/build_shared --target install --parallel $(nproc) && \
    # Build STATIC
    cmake -S /tmp/SDL_ttf -B /tmp/SDL_ttf/build_static \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} -DBUILD_SHARED_LIBS=OFF && \
    cmake --build /tmp/SDL_ttf/build_static --target install --parallel $(nproc) && \
    rm -rf /tmp/SDL_ttf

# Gerar arquivos GLAD (OpenGL 4.6) para C/C++
RUN pip install glad && \
    python3 -m glad --generator=c --api="gl=4.6" --out-path=/tmp/glad
# Criar pastas e mover arquivos
RUN mkdir -p ${LIBRARY_PATH}/lib ${LIBRARY_PATH}/include ${LIBRARY_PATH}/src/glad && \
    mv /tmp/glad/include/glad ${LIBRARY_PATH}/include/ && \
    mv /tmp/glad/src/* ${LIBRARY_PATH}/src/glad/ && \
    rm -rf /tmp/glad
# Build BOTH static and shared GLAD libraries with PIC support
RUN cd ${LIBRARY_PATH}/src/glad && \
    g++ -fPIC -I${LIBRARY_PATH}/include -c glad.c -o glad.o && \
    ar rcs ${LIBRARY_PATH}/lib/libglad.a glad.o && \
    g++ -shared -fPIC glad.c -o ${LIBRARY_PATH}/lib/libglad.so.1.0.0 && \
    ln -sf libglad.so.1.0.0 ${LIBRARY_PATH}/lib/libglad.so.1 && \
    ln -sf libglad.so.1 ${LIBRARY_PATH}/lib/libglad.so && \
    rm glad.o

# DearImGui, PLOG, GLM, Nlohmann JSON are header-only
ENV DEARIMGUI_VERSION="1.92.4"
RUN wget "https://github.com/ocornut/imgui/archive/refs/tags/v${DEARIMGUI_VERSION}.tar.gz" -O /tmp/imgui-${DEARIMGUI_VERSION}.tar.gz && \
    tar -xzf /tmp/imgui-${DEARIMGUI_VERSION}.tar.gz -C /tmp/ && \
    rm /tmp/imgui-${DEARIMGUI_VERSION}.tar.gz
RUN mkdir -p ${LIBRARY_PATH}/include/imgui && \
    mv /tmp/imgui-${DEARIMGUI_VERSION}/* ${LIBRARY_PATH}/include/imgui/ && \
    rm -rf /tmp/imgui-${DEARIMGUI_VERSION}
ENV PLOG_VERSION="1.1.10"
RUN wget "https://github.com/SergiusTheBest/plog/archive/refs/tags/${PLOG_VERSION}.tar.gz" -O /tmp/plog-${PLOG_VERSION}.tar.gz && \
    tar -xzf /tmp/plog-${PLOG_VERSION}.tar.gz -C /tmp/ && \
    rm /tmp/plog-${PLOG_VERSION}.tar.gz
RUN mv /tmp/plog-${PLOG_VERSION}/include/* ${LIBRARY_PATH}/include/ && \
    rm -rf /tmp/plog-${PLOG_VERSION}
ENV GLM_VERSION="1.0.1"
RUN wget "https://github.com/g-truc/glm/archive/refs/tags/${GLM_VERSION}.tar.gz" -O /tmp/glm-${GLM_VERSION}.tar.gz && \
    tar -xzf /tmp/glm-${GLM_VERSION}.tar.gz -C /tmp/ && \
    rm /tmp/glm-${GLM_VERSION}.tar.gz
RUN mv /tmp/glm-${GLM_VERSION}/glm ${LIBRARY_PATH}/include && \
    rm -rf /tmp/glm-${GLM_VERSION}
ENV NLOHMANN_JSON="3.11.3"
RUN wget "https://github.com/nlohmann/json/releases/download/v${NLOHMANN_JSON}/json.tar.xz" -O /tmp/json.tar.xz && \
    tar -xf /tmp/json.tar.xz -C /tmp/ && \
    rm /tmp/json.tar.xz
RUN mv /tmp/json/include/* ${LIBRARY_PATH}/include/ && \
    rm -rf /tmp/json

# C3C is a pre-built compiler
ENV C3C_VERSION="0.7.7"
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
    rm -rf /tmp/SQLiteCpp-${SQLITECPP_VERSION}.tar.gz && \
    # Build SHARED
    # cmake -S /tmp/SQLiteCpp-${SQLITECPP_VERSION} -B /tmp/SQLiteCpp-${SQLITECPP_VERSION}/build_shared \
    #     -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} -DBUILD_SHARED_LIBS=ON \
    #     -DSQLITECPP_INTERNAL_SQLITE=ON && \
    # cmake --build /tmp/SQLiteCpp-${SQLITECPP_VERSION}/build_shared --target install --parallel $(nproc) && \
    # Build STATIC
    cmake -S /tmp/SQLiteCpp-${SQLITECPP_VERSION} -B /tmp/SQLiteCpp-${SQLITECPP_VERSION}/build_static \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} -DBUILD_SHARED_LIBS=OFF \
        -DSQLITECPP_INTERNAL_SQLITE=ON && \
    cmake --build /tmp/SQLiteCpp-${SQLITECPP_VERSION}/build_static --target install --parallel $(nproc) && \
    rm -rf /tmp/SQLiteCpp-${SQLITECPP_VERSION}


# Raylib
ENV RAYLIB_VERSION="5.5"
RUN wget "https://github.com/raysan5/raylib/releases/download/${RAYLIB_VERSION}/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz" -O /tmp/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz && \
    tar -xzf /tmp/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz -C /tmp/ && \
    rm -rf /tmp/raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz
RUN cp -r /tmp/raylib-${RAYLIB_VERSION}_linux_amd64/lib/* ${LIBRARY_PATH}/lib && \
    cp -r /tmp/raylib-${RAYLIB_VERSION}_linux_amd64/include/* ${LIBRARY_PATH}/include/ && \
    rm -rf /tmp/raylib-${RAYLIB_VERSION}_linux_amd64


# oneTBB
RUN cd /tmp && \
    git clone "https://github.com/uxlfoundation/oneTBB.git" && \
    # Build SHARED
    # cmake -S /tmp/oneTBB -B /tmp/oneTBB/build_shared \
    #     -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} -DBUILD_SHARED_LIBS=ON && \
    # cmake --build /tmp/oneTBB/build_shared --target install --parallel $(nproc) && \
    # Build STATIC
    cmake -S /tmp/oneTBB -B /tmp/oneTBB/build_static \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} -DBUILD_SHARED_LIBS=OFF && \
    cmake --build /tmp/oneTBB/build_static --target install --parallel $(nproc) && \
    rm -rf /tmp/oneTBB

# libink
RUN cd /tmp && \
    git clone "https://github.com/Arthu-RL/libink.git" && \
    cmake -S /tmp/libink -B /tmp/libink/build \ 
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} && \
    cmake --build /tmp/libink/build --target install --parallel $(nproc) && \
    rm -rf /tmp/libink

# libwma
RUN cd /tmp && \
    git clone "https://github.com/Arthu-RL/libwma.git" && \
    cmake -S /tmp/libwma -B /tmp/libwma/build \ 
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} && \
    cmake --build /tmp/libwma/build --target install --parallel $(nproc) && \
    rm -rf /tmp/libwma

    
# JWT
ENV JWTCPP_VERSION="0.7.1"
RUN wget "https://github.com/Thalhammer/jwt-cpp/releases/download/v${JWTCPP_VERSION}/jwt-cpp-v${JWTCPP_VERSION}.tar.gz" -O /tmp/jwt-cpp-v${JWTCPP_VERSION}.tar.gz && \
    mkdir -p /tmp/jwt-cpp-v${JWTCPP_VERSION} && \
    tar -xvf /tmp/jwt-cpp-v${JWTCPP_VERSION}.tar.gz -C /tmp/jwt-cpp-v${JWTCPP_VERSION} --strip-components=1 && \
    rm -rf /tmp/jwt-cpp-v${JWTCPP_VERSION}.tar.gz && \
    cmake -S /tmp/jwt-cpp-v${JWTCPP_VERSION} -B /tmp/jwt-cpp-v${JWTCPP_VERSION}/build \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} && \
    cmake --build /tmp/jwt-cpp-v${JWTCPP_VERSION}/build --target install --parallel $(nproc) && \
    rm -rf /tmp/jwt-cpp-v${JWTCPP_VERSION}


# OpenCV apt dependencies
RUN apt-get update && \
    apt-get install -y --install-recommends \
    libglib2.0-0 libdbus-1-3 \
    libgl1-mesa-glx libgl1-mesa-dri libglu1-mesa \
    libegl1 libglx0 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-tools \
    gstreamer1.0-alsa \
    gstreamer1.0-pulseaudio \
    libgstreamer1.0-0 \
    libgstreamer-plugins-base1.0-0 \
    libgstreamer-plugins-bad1.0-0 \
    libpulse0 libpulse-mainloop-glib0 libasound2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/locale/*

# OpenCV
ENV OPENCV_VERSION="4.12.0"
RUN cd /tmp && \
    wget -O opencv.zip https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.zip && \
    wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/refs/tags/${OPENCV_VERSION}.zip && \
    unzip opencv.zip && \
    unzip opencv_contrib.zip && \
    mv opencv-${OPENCV_VERSION} opencv && \
    mv opencv_contrib-${OPENCV_VERSION} opencv_contrib

# Common OpenCV flags
ENV OPENCV_FLAGS=" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} \
        -DOPENCV_EXTRA_MODULES_PATH=/tmp/opencv_contrib/modules \
        -DBUILD_opencv_python3=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DWITH_TBB=ON \
        -DTBB_DIR=${LIBRARY_PATH}/lib/cmake/TBB \
        -DWITH_CUDA=ON \
        -DCUDA_TOOLKIT_ROOT_DIR=${LIBRARY_PATH}/cuda \
        -DCMAKE_CUDA_ARCHITECTURES=61;70;75;80;86;89 \
        -DOPENCV_DNN_CUDA=ON \
        -DWITH_CUDNN=ON \
        -DCMAKE_CXX_STANDARD=17 \
        -DBUILD_TESTS=OFF \
        -DBUILD_PERF_TESTS=OFF"

# Build SHARED
# RUN cmake -S /tmp/opencv -B /tmp/opencv/build_shared \
#         ${OPENCV_FLAGS} -DBUILD_SHARED_LIBS=ON && \
#     cmake --build /tmp/opencv/build_shared --target install --parallel $(nproc)

# Build STATIC
RUN cmake -S /tmp/opencv -B /tmp/opencv/build_static \
        ${OPENCV_FLAGS} -DBUILD_SHARED_LIBS=OFF && \
    cmake --build /tmp/opencv/build_static --target install --parallel $(nproc) && \
    rm -rf /tmp/opencv /tmp/opencv_contrib /tmp/opencv.zip /tmp/opencv_contrib.zip


############################################
# TENSORRT BUILD
############################################
ENV TENSORRT_VERSION="10.13.3"

RUN pip3 install --no-cache-dir onnx numpy

# É necessário download da lib no site official manualmente e depois fazer COPY
# RUN wget "https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/${TENSORRT_VERSION}/tars/TensorRT-${TENSORRT_VERSION}.9.Linux.x86_64-gnu.cuda-12.9.tar.gz" -O /tmp/tensorrt.tar.gz && \
COPY TensorRT-${TENSORRT_VERSION}.9/ ${LIBRARY_PATH}/tensorrt/

# Build the open-source parsers (both static/shared) against the SDK
RUN git clone --branch v${TENSORRT_VERSION} --recursive https://github.com/NVIDIA/TensorRT.git /tmp/TensorRT

# Common TensorRT Parser flags
ENV TRT_PARSER_FLAGS=" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} \
        -DTENSORRT_INSTALL_DIR=${LIBRARY_PATH}/tensorrt \
        -DCUDA_TOOLKIT_ROOT_DIR=${LIBRARY_PATH}/cuda \
        -DCMAKE_CUDA_COMPILER=${LIBRARY_PATH}/cuda/bin/nvcc \
        -DCMAKE_CUDA_ARCHITECTURES=61;70;75;80;86;89 \
        -DTRT_LIB_DIR=${LIBRARY_PATH}/tensorrt/lib \
        -DTRT_BIN_DIR=${LIBRARY_PATH}/tensorrt/bin \
        -DBUILD_PARSERS=ON \
        -DBUILD_PLUGINS=OFF \
        -DBUILD_SAMPLES=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_PYTHON=OFF \
        -DBUILD_ONNX_PARSER=ON \
        -DONNX_NAMESPACE=onnx"

# Build SHARED parsers
# RUN cmake -S /tmp/TensorRT -B /tmp/TensorRT/build_shared \
#         ${TRT_PARSER_FLAGS} -DBUILD_SHARED_LIBS=ON && \
#     cmake --build /tmp/TensorRT/build_shared --target install --parallel $(nproc)

# Build STATIC parsers
RUN cmake -S /tmp/TensorRT -B /tmp/TensorRT/build_static \
        ${TRT_PARSER_FLAGS} -DBUILD_SHARED_LIBS=OFF && \
    cmake --build /tmp/TensorRT/build_static --target install --parallel $(nproc) && \
    rm -rf /tmp/TensorRT


############################################
# Environment set up
############################################
ENV CPLUS_INCLUDE_PATH="${LIBRARY_PATH}/include:${LIBRARY_PATH}/tensorrt/include:${LIBRARY_PATH}/cuda/include"
ENV LD_LIBRARY_PATH="${LIBRARY_PATH}/lib:${LIBRARY_PATH}/tensorrt/lib:${LIBRARY_PATH}/cuda/lib64:${LD_LIBRARY_PATH}"
ENV PATH="${LIBRARY_PATH}/cuda/bin:${LIBRARY_PATH}/tensorrt/bin:${PATH}"
ENV PKG_CONFIG_PATH="${LIBRARY_PATH}/lib/pkgconfig:${LIBRARY_PATH}/lib/cmake/TBB:${PKG_CONFIG_PATH}"


############################################
# Clean apt
############################################
RUN apt-get clean && apt-get autoremove -y


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