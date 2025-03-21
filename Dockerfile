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
    git clone https://github.com/libsdl-org/SDL.git -b SDL2 && \
    cmake -S /tmp/SDL -B /tmp/SDL/build -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} \
    -DSDL_ALSA=ON \
    -DSDL_OPENGL=ON \
    -DSDL_VULKAN=ON && \
    cmake --build /tmp/SDL/build --target install --parallel $(nproc) && \
    rm -rf /tmp/SDL


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
	git clone "https://github.com/libsdl-org/SDL_ttf.git" -b SDL2 && \
	cmake -S /tmp/SDL_ttf -B /tmp/SDL_ttf/build -DCMAKE_INSTALL_PREFIX=${LIBRARY_PATH} && \
	cmake --build /tmp/SDL_ttf/build --target install --parallel $(nproc) && \
	rm -rf /tmp/SDL_ttf

ENV INKLIB_VERSION="1.0.0"
RUN wget "https://github.com/Arthu-RL/libink/releases/download/${INKLIB_VERSION}/ink-${INKLIB_VERSION}_linux_amd64.tar.gz" -O /tmp/ink-${INKLIB_VERSION}_linux_amd64.tar.gz && \
    tar -xzf /tmp/ink-${INKLIB_VERSION}_linux_amd64.tar.gz -C /tmp/ && \
    rm -rf /tmp/ink-${INKLIB_VERSION}_linux_amd64.tar.gz

RUN cp -r /tmp/ink-${INKLIB_VERSION}_linux_amd64/lib/* ${LIBRARY_PATH}/lib && \
    cp -r /tmp/ink-${INKLIB_VERSION}_linux_amd64/include/* ${LIBRARY_PATH}/include/ && \
    rm -rf /tmp/ink-${INKLIB_VERSION}_linux_amd64

############################################
# Important environment variables set up
############################################
ENV VULKAN_ROOT="${LIBRARY_PATH}/VulkanSDK/${VULKAN_SDK_VERSION}"
RUN chmod +x ${VULKAN_ROOT}/setup-env.sh && \
    echo "source ${VULKAN_ROOT}/setup-env.sh" >> ~/.bashrc


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
