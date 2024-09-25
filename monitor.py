import time
import psutil
import logging

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')

def log_system_usage():
    # Get CPU and Memory usage
    cpu_usage = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    logging.info(f"CPU Usage: {cpu_usage}%")
    logging.info(f"Memory Usage: {memory.percent}% used out of {memory.total / (1024 ** 3):.2f} GB")

if __name__ == "__main__":
    logging.info("Starting system resource monitor...")
    while True:
        log_system_usage()
        time.sleep(120)
