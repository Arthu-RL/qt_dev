# Vulkan Development Environment

This repository provides a Docker image for building and developing applications using **Qt**, **Qt Creator**, **Vulkan**, and **CUDA** with support for **X11**.

## Overview

The Docker image builds the following technologies from source:

- **Qt**: A cross-platform application framework.
- **Qt Creator**: An integrated development environment (IDE) for Qt applications.
- **Vulkan**: A low-overhead, cross-platform 3D graphics and compute API.
- **CUDA**: A parallel computing platform and application programming interface model created by NVIDIA.

## Build the Docker Image

To build the Docker image with the desired configurations, run the following command:

```bash
python build_run.py
```

Replace `custom_tag` with your preferred tag name for the image.

## Run the Docker Container

To run the Docker container with the built image, use the following command:

```bash
python build_run.py --run
```

Make sure to replace `vulkan_dev` with your desired container name.

## Technologies Included

This image integrates several key technologies:

- **[CMake](https://github.com/Kitware/CMake)**: A cross-platform tool for managing the build process of software.
- **[GLFW](https://github.com/glfw/glfw)**: A library for creating windows and handling input, particularly useful for OpenGL and Vulkan applications.
- **[CUDA](https://developer.download.nvidia.com/compute/cuda/repos/)**: NVIDIA's parallel computing platform for accelerating computing applications.
- **[Vulkan SDK](https://vulkan.lunarg.com/sdk/)**: A software development kit for Vulkan applications.
- **[LLVM](https://apt.llvm.org/)**: A collection of modular and reusable compiler and toolchain technologies.
- **[Qt Creator](https://download.qt.io/official_releases/qtcreator/)**: A powerful IDE for developing Qt applications.

## Contributing

If you'd like to contribute to this project, please fork the repository and submit a pull request with your improvements or bug fixes.

### Issues

If you encounter any issues, please open an issue in the repository for tracking.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
