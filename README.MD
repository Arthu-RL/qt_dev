# Qt Development Environment

This repository provides a Docker image for building and developing applications for education/learning purposes using **Qt**, **Qt Creator**, **Vulkan**, **GLFW**, **Dear ImGui**, **CUDA**, and other tools with support for **X11**.

---

## 🧰 Technologies Included

The Docker environment that you can build includes:

* **[CMake](https://github.com/Kitware/CMake)** (Apache 2.0)
* **[GLFW](https://github.com/glfw/glfw)** (zlib/libpng license)
* **[Vulkan SDK](https://vulkan.lunarg.com/sdk/)** (Apache 2.0 / MIT depending on component)
* **[LLVM & Clang](https://llvm.org/)** (Apache 2.0 with LLVM Exception)
* **[FFmpeg](https://ffmpeg.org/)** (LGPL/GPL depending on configuration)
* **[Qt 6](https://www.qt.io/)** (GPLv3 or Commercial License)
* **[Qt Creator](https://www.qt.io/product/development-tools)** (GPLv3)
* **[Dear ImGui](https://github.com/ocornut/imgui)** (MIT)
* **[SDL3](https://github.com/libsdl-org/SDL)** (zlib License)
* **[SDL3_ttf](https://github.com/libsdl-org/SDL_ttf)** (zlib License)
* **[GLAD](https://github.com/Dav1dde/glad)** (Apache 2.0)
* **[GLM](https://github.com/g-truc/glm)** (MIT License)
* **[nlohmann/json](https://github.com/nlohmann/json)** (MIT License)
* **[SQLiteCpp](https://github.com/SRombauts/SQLiteCpp)** (MIT License)
* **[raylib](https://www.raylib.com/)** (zlib License)
* **[libink](https://github.com/Arthu-RL/libink)** (MIT License)
* **[ONNX Runtime](https://github.com/microsoft/onnxruntime)** (MIT License)
* **[stb libraries](https://github.com/nothings/stb)** (Public Domain / MIT License)
* **[Emscripten](https://emscripten.org/)** (MIT / NCSA Open Source License)
* **[Gradle](https://gradle.org/)** (Apache 2.0)

---

## 🔧 Build the Docker Image

To build the Docker image:

```bash
python3 build_run.py --build --base --retry 2 --image_tag="base"
python3 build_run.py --build --retry 2 --image_tag="lts"
```

## 🔧 Run the Docker Image

To run the Docker image:

```bash
python3 build_run.py --run --image_tag="lts"
```

Before starting the container, instead of doing `xhost +` command, do this:

```sh
alias start_vulkan_dev="cat $XAUTHORITY > ~/.docker_xauth && docker start vulkan-dev"
```