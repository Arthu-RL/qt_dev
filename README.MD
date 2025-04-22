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

---

## 🚨 License and Legal Compliance

This repository and Dockerfile are licensed under the **MIT License** (see [LICENSE](LICENSE)).

However, this project **builds and installs third-party libraries and software** under a variety of licenses. You are responsible for complying with their respective licenses when using or distributing this Docker image.

### ⚠️ Key Licensing Notes

| Component         | License Type                            | Notes |
|-------------------|------------------------------------------|-------|
| **NVIDIA CUDA & cuDNN** | Proprietary (EULA) | You must accept the [CUDA EULA](https://developer.nvidia.com/cuda-eula) and [cuDNN Software License](https://developer.nvidia.com/cudnn-license) before using these components. |
| **Qt & Qt Creator** | GPLv3 | Redistribution of the compiled environment requires compliance with the GPL. |
| **FFmpeg** | LGPL/GPL | If you enable GPL components, redistribution must be GPL-compliant. |
| **LLVM, Clang** | Apache 2.0 + LLVM Exception | Safe for open-source use. |
| **Dear ImGui** | MIT | Fully permissive. |

It is strongly recommended that you:

- Review the [Qt licensing page](https://www.qt.io/licensing) if you intend to distribute this environment or use Qt in commercial projects.
- Ensure your **use and distribution of NVIDIA tools** is compliant with their EULA.
- **Avoid distributing the built image publicly unless you comply** with all these license obligations.

---

## 🔧 Build the Docker Image

To build the Docker image:

```bash
python build_run.py --build --base --retry 3 --image_tag="base"
python build_run.py --build --image_tag="1.0"
```
