###########################################
#  arthurrl/vulkan-dev:base as the base image 
###########################################
FROM arthurrl/vulkan-dev:base


###########################################
#  Build Args
###########################################
# Empty


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


# Clone and install SDL2 from source
RUN cd /tmp && \
    git clone "https://github.com/libsdl-org/SDL.git" -b SDL2 && \
    cmake -S /tmp/SDL -B /tmp/SDL/build -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} \
    -DSDL_ALSA=ON \
    -DSDL_OPENGL=ON \
    -DSDL_VULKAN=ON && \
    cmake --build /tmp/SDL/build --target install --parallel $(nproc) && \
    rm -rf /tmp/SDL


RUN cd /tmp && \
	git clone "https://github.com/libsdl-org/SDL_ttf.git" -b SDL2 && \
	cmake -S /tmp/SDL_ttf -B /tmp/SDL_ttf/build -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} && \
	cmake --build /tmp/SDL_ttf/build --target install --parallel $(nproc) && \
	rm -rf /tmp/SDL_ttf


# Download and install GLAD-generated files (OpenGL)
RUN pip3 install --upgrade "git+https://github.com/dav1dde/glad.git#egg=glad" && \
    python3 -m glad --api="gl:core=4.6" --out-path=/tmp/glad

RUN mkdir -p ${LIBRARY_PATH}/src/glad && \
    mv /tmp/glad/include/glad ${LIBRARY_PATH}/include/ && \
    mv /tmp/glad/src/* ${LIBRARY_PATH}/src/glad/ && \
    rm -rf /tmp/glad

RUN g++ -c ${LIBRARY_PATH}/src/glad/gl.c -o ${LIBRARY_PATH}/src/glad/glad.o && \
    ar rcs ${LIBRARY_PATH}/lib/libglad.a ${LIBRARY_PATH}/src/glad/glad.o && \
    rm ${LIBRARY_PATH}/src/glad/glad.o


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
    cp -r /tmp/raylib-${RAYLIB_VERSION}_linux_amd64/include/* ${LIBRARY_PATH}/include/ && \
    rm -rf /tmp/raylib-${RAYLIB_VERSION}_linux_amd64


RUN cd /tmp && \
	git clone "https://github.com/uxlfoundation/oneTBB.git" && \
	cmake -S /tmp/oneTBB -B /tmp/oneTBB/build \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} \ 
        -DBUILD_SHARED_LIBS=OFF && \
	cmake --build /tmp/oneTBB/build --target install --parallel $(nproc) && \
	rm -rf /tmp/oneTBB


RUN cd /tmp && \
    git clone "https://github.com/Arthu-RL/libink.git" && \
    cmake -S /tmp/libink -B /tmp/libink/build \ 
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} && \
    cmake --build /tmp/libink/build --target install --parallel $(nproc) && \
    rm -rf /tmp/libink


RUN cd /tmp && \
    git clone "https://github.com/opencv/opencv.git" && \
    git clone "https://github.com/opencv/opencv_contrib.git" && \
    cmake -S /tmp/opencv -B /tmp/opencv/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} \
        -DBUILD_SHARED_LIBS=OFF \
        -DOPENCV_EXTRA_MODULES_PATH=/tmp/opencv_contrib/modules \
        -DBUILD_opencv_python3=OFF \
        -DBUILD_opencv_python2=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DWITH_CUDA=ON \
        -DWITH_CUDNN=ON \
        -DOPENCV_DNN_CUDA=ON \
        -DWITH_OPENGL=ON \
        -DWITH_V4L=ON \
        -DWITH_GTK=ON \
        -DWITH_TBB=ON \
        -DTBB_DIR=${LIBRARY_PATH}/lib/cmake/TBB \
        -DBUILD_TESTS=OFF \
        -DBUILD_PERF_TESTS=OFF && \
    cmake --build /tmp/opencv/build --target install --parallel $(nproc) && \
    rm -rf /tmp/opencv /tmp/opencv_contrib


ENV TENSORRT_VERSION="10.9.0"
RUN wget "https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/${TENSORRT_VERSION}/tars/TensorRT-${TENSORRT_VERSION}.34.Linux.x86_64-gnu.cuda-12.8.tar.gz" -O /tmp/tensorrt.tar.gz
RUN mkdir -p ${LIBRARY_PATH}/tensorrt && \
    tar -xzf /tmp/tensorrt.tar.gz -C ${LIBRARY_PATH}/tensorrt --strip-components=1 && \
    rm /tmp/tensorrt.tar.gz
RUN echo "${LIBRARY_PATH}/tensorrt/lib" > /etc/ld.so.conf.d/tensorrt.conf && ldconfig


RUN pip3 install onnx
RUN cd /tmp && \
    git clone --recursive "https://github.com/NVIDIA/TensorRT.git" && \
    cmake -S /tmp/TensorRT -B /tmp/TensorRT/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} \
        -DCUDA_TOOLKIT_ROOT_DIR=${LIBRARY_PATH}/cuda \
        -DCMAKE_CUDA_COMPILER=${LIBRARY_PATH}/cuda/bin/nvcc \
        -DCMAKE_CUDA_ARCHITECTURES="50;52;60;61;70;75;80;86" \
        -DTRT_LIB_DIR=${LIBRARY_PATH}/tensorrt/lib \
        -Dnvinfer_LIB_PATH=${LIBRARY_PATH}/tensorrt/lib/libnvinfer.so \
        -DTRT_BIN_DIR=${LIBRARY_PATH}/bin \
        -DBUILD_PARSERS=ON \
        -DBUILD_PLUGINS=ON \
        -DBUILD_SAMPLES=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_PYTHON=OFF \
        -DBUILD_ONNX_PARSER=ON \
        -DONNX_NAMESPACE=onnx && \
    cmake --build /tmp/TensorRT/build --target install --parallel $(nproc) && \
    rm -rf /tmp/TensorRT


############################################
# Important environment variables set up
############################################
ENV VULKAN_ROOT="${LIBRARY_PATH}/VulkanSDK/${VULKAN_SDK_VERSION}"
RUN chmod +x ${VULKAN_ROOT}/setup-env.sh && \
    echo "source ${VULKAN_ROOT}/setup-env.sh" >> ~/.bashrc

# Set include paths for compilation
ENV CPLUS_INCLUDE_PATH="${LIBRARY_PATH}/include:${LIBRARY_PATH}/tensorrt/include:${LIBRARY_PATH}/cuda/include:$CPLUS_INCLUDE_PATH"
ENV LD_LIBRARY_PATH="${LIBRARY_PATH}/lib:${LIBRARY_PATH}/tensorrt/lib:${LIBRARY_PATH}/cuda/lib64:$LD_LIBRARY_PATH"
ENV PATH="${LIBRARY_PATH}/cuda/bin:$PATH"
ENV PKG_CONFIG_PATH="${LIBRARY_PATH}/lib/pkgconfig:$PKG_CONFIG_PATH"


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

WORKDIR ["/workspace"]

# Default shell for interactive debugging (optional)
SHELL ["/bin/bash", "-c"]

# Run the Python script
ENTRYPOINT ["python3", "-u", "/app/monitor.py"]
