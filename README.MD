# Vulkan Development Environment

This repository provides a Docker image for building and developing applications using **Qt**, **Qt Creator**, **Vulkan**, **GLFW**, **Dear ImGui**, **CUDA**, and other tools with support for **X11**.

---

## 🧰 Technologies Included

This Docker environment includes:

- **[CMake](https://github.com/Kitware/CMake)** (Apache 2.0)
- **[GLFW](https://github.com/glfw/glfw)** (zlib/libpng license)
- **[CUDA](https://developer.nvidia.com/cuda-zone)** (Proprietary NVIDIA License)
- **[cuDNN](https://developer.nvidia.com/cudnn)** (Proprietary NVIDIA License)
- **[Vulkan SDK](https://vulkan.lunarg.com/sdk/)** (Apache 2.0 / MIT depending on component)
- **[LLVM & Clang](https://llvm.org/)** (Apache 2.0 with LLVM Exception)
- **[FFmpeg](https://ffmpeg.org/)** (LGPL/GPL depending on configuration)
- **[Qt 6](https://www.qt.io/)** (GPLv3 or Commercial License)
- **[Qt Creator](https://www.qt.io/product/development-tools)** (GPLv3)
- **[Dear ImGui](https://github.com/ocornut/imgui)** (MIT)

## 🔧 Build the Docker Image

To build the Docker image:

```bash
python build_run.py --build --base --retry 3 --image_tag="base"
python build_run.py --build --image_tag="1.0"
```
