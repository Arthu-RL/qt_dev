# Vulkan Development Environment

This repository provides a Docker image for building and developing applications for education/learning purposes using **Qt**, **Qt Creator**, **Vulkan**, **GLFW**, **Dear ImGui**, **CUDA**, and other tools with support for **X11**.

---

## 🧰 Technologies Included

The Docker environment that you can build includes:

- **[CMake](https://github.com/Kitware/CMake)** (Apache 2.0)
- **[GLFW](https://github.com/glfw/glfw)** (zlib/libpng license)
- **[CUDA](https://developer.nvidia.com/cuda-zone)** (Proprietary NVIDIA License)
- **[cuDNN](https://developer.nvidia.com/cudnn)** (Proprietary NVIDIA License)
- **[TensorRT](https://developer.nvidia.com/tensorrt)** (Proprietary NVIDIA License)
- **[Vulkan SDK](https://vulkan.lunarg.com/sdk/)** (Apache 2.0 / MIT depending on component)
- **[LLVM & Clang](https://llvm.org/)** (Apache 2.0 with LLVM Exception)
- **[FFmpeg](https://ffmpeg.org/)** (LGPL/GPL depending on configuration)
- **[Qt 6](https://www.qt.io/)** (GPLv3 or Commercial License)
- **[Qt Creator](https://www.qt.io/product/development-tools)** (GPLv3)
- **[Dear ImGui](https://github.com/ocornut/imgui)** (MIT)
- **[SDL2](https://github.com/libsdl-org/SDL)** (zlib License)
- **[SDL_ttf](https://github.com/libsdl-org/SDL_ttf)** (zlib License)
- **[GLAD](https://github.com/Dav1dde/glad)** (Apache 2.0)
- **[PLOG](https://github.com/SergiusTheBest/plog)** (MIT License)
- **[GLM](https://github.com/g-truc/glm)** (MIT License)
- **[nlohmann/json](https://github.com/nlohmann/json)** (MIT License)
- **[SQLiteCpp](https://github.com/SRombauts/SQLiteCpp)** (MIT License)
- **[raylib](https://www.raylib.com/)** (zlib License)
- **[oneTBB (Intel TBB)](https://github.com/oneapi-src/oneTBB)** (Apache 2.0 License)
- **[OpenCV](https://opencv.org/)** (Apache 2.0 License)
- **[C3C Compiler](https://github.com/c3lang/c3c)** (LGPL-3.0 License)
- **[libink](https://github.com/Arthu-RL/libink)** (MIT License)

---

## 🔧 Build the Docker Image

To build the Docker image:

```bash
python build_run.py --build --base --retry 3 --image_tag="base"
python build_run.py --build --image_tag="1.0"
```

## 🔧 Run the Docker Image

To run the Docker image:

```bash
python build_run.py --run --image_tag="1.0"
```
