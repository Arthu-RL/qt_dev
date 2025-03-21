import time
import psutil
import os
import subprocess as sp

def log_system_usage():
    # Get CPU and Memory usage
    cpu_usage = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    swap = psutil.swap_memory()

    print(f"CPU Usage: {cpu_usage}%")
    print(f"Memory Usage: {memory.percent}% used out of {memory.total / (1024 ** 3):.2f} GB")
    print(f"Swap Usage: {swap.percent}% used out of {swap.total / (1024 ** 3):.2f} GB")

if __name__ == "__main__":
    print("Welcome to QtCreator dev container for VULKAN!")
    print()
    print(f"CMAKE_VERSION: {os.getenv('CMAKE_VERSION')}")
    print(f"CUDA_VERSION: {os.getenv('CUDA_VERSION')}")
    print(f"QTCREATOR_VERSION: {os.getenv('QTCREATOR_VERSION')}")
    print(f"QT: {os.getenv('QT')}")
    print(f"VULKAN_SDK_VERSION: {os.getenv('VULKAN_SDK_VERSION')}")
    print(f"GLFW_VERSION: {os.getenv('GLFW_VERSION')}")
    print(f"PLOG_VERSION: {os.getenv('PLOG_VERSION')}")
    print(f"GLM_VERSION: {os.getenv('GLM_VERSION')}")
    print()
    
    result = sp.run("nvidia-smi", shell=True, capture_output=True, text=True)
    print(result.stderr)
    print()

    print("Starting system resource monitor...")
    print()

    while True:
        log_system_usage()
        time.sleep(180)
