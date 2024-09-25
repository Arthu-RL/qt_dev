import time
import psutil
import logging
from pynvml import nvmlInit, nvmlDeviceGetHandleByIndex, nvmlDeviceGetMemoryInfo, nvmlDeviceGetUtilizationRates, nvmlShutdown

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

# Initialize NVML (NVIDIA Management Library)
nvmlInit()

def log_system_usage():
    # Get CPU and Memory usage
    cpu_usage = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    logging.info(f"CPU Usage: {cpu_usage}%")
    logging.info(f"Memory Usage: {memory.percent}% used out of {memory.total / (1024 ** 3):.2f} GB")

    # GPU Monitoring
    try:
        gpu_handle = nvmlDeviceGetHandleByIndex(0)  # Assuming the first GPU
        gpu_memory = nvmlDeviceGetMemoryInfo(gpu_handle)
        gpu_utilization = nvmlDeviceGetUtilizationRates(gpu_handle)
        
        # GPU usage information
        gpu_memory_used = gpu_memory.used / (1024 ** 2)  # Convert to MB
        gpu_memory_total = gpu_memory.total / (1024 ** 2)  # Convert to MB
        logging.info(f"GPU Memory Usage: {gpu_memory_used:.2f} MB used out of {gpu_memory_total:.2f} MB")
        logging.info(f"GPU Utilization: {gpu_utilization.gpu}%")
    except Exception as e:
        logging.error(f"Error fetching GPU usage data: {e}")

if __name__ == "__main__":
    logging.info("Starting system resource monitor...")
    while True:
        try:
            log_system_usage()
        finally:
            nvmlShutdown()
        time.sleep(120)
