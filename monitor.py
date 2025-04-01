#!/usr/bin/env python3
import time
import psutil
import os
import subprocess as sp
import json
from datetime import datetime
import signal
import sys
import threading
import queue
import re
from collections import deque

# Configuration
CONFIG = {
    "container_name": "VULKAN-DEV",
    "log_interval": 60,  # seconds
    "history_size": 10,  # data points to keep for trend analysis
    "gpu_poll_interval": 5,  # seconds
    "alert_thresholds": {
        "cpu": 80,  # percent
        "memory": 85,  # percent
        "gpu_memory": 85,  # percent
        "gpu_temp": 80,  # celsius
        "disk": 90,  # percent
    }
}

# Store historical data for trend analysis
history = {
    "cpu": deque(maxlen=CONFIG["history_size"]),
    "memory": deque(maxlen=CONFIG["history_size"]),
    "gpu_util": deque(maxlen=CONFIG["history_size"]),
    "gpu_memory": deque(maxlen=CONFIG["history_size"]),
    "disk_io": deque(maxlen=CONFIG["history_size"]),
    "net_io": deque(maxlen=CONFIG["history_size"]),
}

# Shared queue for GPU metrics
gpu_metrics_queue = queue.Queue()

class ColoredOutput:
    """ANSI color codes for terminal output"""
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    print(f"\n{ColoredOutput.YELLOW}Shutting down VULKAN-DEV monitoring system...{ColoredOutput.ENDC}")
    sys.exit(0)

def get_container_info():
    """Get information about the container and its environment"""
    container_info = {
        "name": CONFIG["container_name"],
        "hostname": os.uname().nodename,
        "environment_vars": {
            "CMAKE_VERSION": os.getenv('CMAKE_VERSION', 'N/A'),
            "CUDA_VERSION": os.getenv('CUDA_VERSION', 'N/A'),
            "QTCREATOR_VERSION": os.getenv('QTCREATOR_VERSION', 'N/A'),
            "QT": os.getenv('QT', 'N/A'),
            "VULKAN_SDK_VERSION": os.getenv('VULKAN_SDK_VERSION', 'N/A'),
            "GLFW_VERSION": os.getenv('GLFW_VERSION', 'N/A'),
            "PLOG_VERSION": os.getenv('PLOG_VERSION', 'N/A'),
            "GLM_VERSION": os.getenv('GLM_VERSION', 'N/A')
        }
    }
    return container_info

def get_vulkan_info():
    """Get Vulkan-specific information if available"""
    vulkan_info = {}
    
    try:
        # Try to get Vulkan drivers and devices info using vulkaninfo
        result = sp.run("vulkaninfo --summary", shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            # Extract Vulkan version
            version_match = re.search(r'Vulkan API Version: (\d+\.\d+\.\d+)', result.stdout)
            if version_match:
                vulkan_info['api_version'] = version_match.group(1)
            
            # Extract GPU device info
            device_matches = re.findall(r'GPU(\d+): (.*?)\n', result.stdout)
            vulkan_info['devices'] = [{'id': m[0], 'name': m[1].strip()} for m in device_matches]
    except:
        pass
    
    return vulkan_info

def get_system_metrics():
    """Get comprehensive system metrics"""
    metrics = {}
    
    # CPU metrics
    cpu_metrics = {
        "overall_percent": psutil.cpu_percent(interval=0.5),
        "per_cpu_percent": psutil.cpu_percent(interval=0.5, percpu=True),
        "load_avg": os.getloadavg() if hasattr(os, 'getloadavg') else None,
        "core_count": psutil.cpu_count(logical=False),
        "thread_count": psutil.cpu_count(logical=True),
        "freq": psutil.cpu_freq().current if psutil.cpu_freq() else None
    }
    metrics["cpu"] = cpu_metrics
    history["cpu"].append(cpu_metrics["overall_percent"])
    
    # Memory metrics
    memory = psutil.virtual_memory()
    swap = psutil.swap_memory()
    memory_metrics = {
        "total_gb": round(memory.total / (1024 ** 3), 2),
        "used_gb": round(memory.used / (1024 ** 3), 2),
        "free_gb": round(memory.available / (1024 ** 3), 2),
        "percent": memory.percent,
        "swap_total_gb": round(swap.total / (1024 ** 3), 2),
        "swap_used_gb": round(swap.used / (1024 ** 3), 2),
        "swap_percent": swap.percent
    }
    metrics["memory"] = memory_metrics
    history["memory"].append(memory_metrics["percent"])
    
    # Disk metrics
    disk = psutil.disk_usage('/')
    disk_io = psutil.disk_io_counters()
    disk_metrics = {
        "total_gb": round(disk.total / (1024 ** 3), 2),
        "used_gb": round(disk.used / (1024 ** 3), 2),
        "free_gb": round(disk.free / (1024 ** 3), 2),
        "percent": disk.percent,
        "read_mb": round(disk_io.read_bytes / (1024 ** 2), 2) if disk_io else 0,
        "write_mb": round(disk_io.write_bytes / (1024 ** 2), 2) if disk_io else 0
    }
    metrics["disk"] = disk_metrics
    
    if disk_io:
        history["disk_io"].append({
            "read_mb": disk_metrics["read_mb"],
            "write_mb": disk_metrics["write_mb"]
        })
    
    # Network metrics
    net_io = psutil.net_io_counters()
    network_metrics = {
        "bytes_sent_mb": round(net_io.bytes_sent / (1024 ** 2), 2),
        "bytes_recv_mb": round(net_io.bytes_recv / (1024 ** 2), 2),
        "packets_sent": net_io.packets_sent,
        "packets_recv": net_io.packets_recv,
        "errin": net_io.errin,
        "errout": net_io.errout,
        "dropin": net_io.dropin,
        "dropout": net_io.dropout
    }
    metrics["network"] = network_metrics
    history["net_io"].append({
        "sent_mb": network_metrics["bytes_sent_mb"],
        "recv_mb": network_metrics["bytes_recv_mb"]
    })
    
    # Process metrics - get top CPU and memory processes
    processes = []
    for proc in sorted(psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']), 
                       key=lambda p: p.info['cpu_percent'], 
                       reverse=True)[:5]:
        try:
            processes.append({
                "pid": proc.info['pid'],
                "name": proc.info['name'],
                "cpu_percent": proc.info['cpu_percent'],
                "memory_percent": proc.info['memory_percent']
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    metrics["top_processes"] = processes
    
    # GPU metrics from the queue if available
    try:
        if not gpu_metrics_queue.empty():
            metrics["gpu"] = gpu_metrics_queue.get(block=False)
            if "utilization" in metrics["gpu"]:
                history["gpu_util"].append(metrics["gpu"]["utilization"])
            if "memory_percent" in metrics["gpu"]:
                history["gpu_memory"].append(metrics["gpu"]["memory_percent"])
    except queue.Empty:
        pass
    
    return metrics

def collect_gpu_metrics():
    """Collect GPU metrics in a separate thread"""
    while True:
        try:
            gpu_metrics = {}
            
            # Try to get NVIDIA GPU metrics using nvidia-smi
            result = sp.run("nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits", 
                         shell=True, capture_output=True, text=True)
            
            if result.returncode == 0 and result.stdout.strip():
                # Parse the output
                gpu_data = result.stdout.strip().split(',')
                if len(gpu_data) >= 4:
                    utilization = float(gpu_data[0].strip())
                    memory_used = float(gpu_data[1].strip())
                    memory_total = float(gpu_data[2].strip())
                    temperature = float(gpu_data[3].strip())
                    
                    memory_percent = (memory_used / memory_total) * 100 if memory_total > 0 else 0
                    
                    gpu_metrics = {
                        "utilization": utilization,
                        "memory_used_mb": memory_used,
                        "memory_total_mb": memory_total,
                        "memory_percent": memory_percent,
                        "temperature": temperature
                    }
                    
                    # Put metrics in the queue for the main thread
                    gpu_metrics_queue.put(gpu_metrics)
            
        except Exception as e:
            pass
            
        time.sleep(CONFIG["gpu_poll_interval"])

def calculate_trends(history_data):
    """Calculate trends from historical data"""
    trends = {}
    
    for metric, values in history_data.items():
        if len(values) >= 2:
            if metric in ["cpu", "memory", "gpu_util", "gpu_memory"]:
                # Simple trend calculation
                first_half = list(values)[:len(values)//2]
                second_half = list(values)[len(values)//2:]
                
                first_avg = sum(first_half) / len(first_half) if first_half else 0
                second_avg = sum(second_half) / len(second_half) if second_half else 0
                
                if first_avg > 0:
                    change = ((second_avg - first_avg) / first_avg) * 100
                    trends[metric] = change
            elif metric in ["disk_io", "net_io"]:
                # For dictionaries of values
                if values and isinstance(values[0], dict):
                    for key in values[0].keys():
                        first_half = [v[key] for v in list(values)[:len(values)//2] if key in v]
                        second_half = [v[key] for v in list(values)[len(values)//2:] if key in v]
                        
                        first_avg = sum(first_half) / len(first_half) if first_half else 0
                        second_avg = sum(second_half) / len(second_half) if second_half else 0
                        
                        if first_avg > 0:
                            change = ((second_avg - first_avg) / first_avg) * 100
                            trends[f"{metric}_{key}"] = change
    
    return trends

def detect_anomalies(metrics, thresholds):
    """Detect anomalies in the metrics based on thresholds"""
    anomalies = []
    
    # CPU usage
    if metrics["cpu"]["overall_percent"] > thresholds["cpu"]:
        anomalies.append({
            "type": "cpu",
            "message": f"High CPU usage: {metrics['cpu']['overall_percent']}%",
            "value": metrics["cpu"]["overall_percent"],
            "threshold": thresholds["cpu"],
            "severity": "critical" if metrics["cpu"]["overall_percent"] > thresholds["cpu"] + 10 else "warning"
        })
    
    # Memory usage
    if metrics["memory"]["percent"] > thresholds["memory"]:
        anomalies.append({
            "type": "memory",
            "message": f"High memory usage: {metrics['memory']['percent']}%",
            "value": metrics["memory"]["percent"],
            "threshold": thresholds["memory"],
            "severity": "critical" if metrics["memory"]["percent"] > thresholds["memory"] + 10 else "warning"
        })
    
    # Disk usage
    if metrics["disk"]["percent"] > thresholds["disk"]:
        anomalies.append({
            "type": "disk",
            "message": f"High disk usage: {metrics['disk']['percent']}%",
            "value": metrics["disk"]["percent"],
            "threshold": thresholds["disk"],
            "severity": "critical" if metrics["disk"]["percent"] > thresholds["disk"] + 5 else "warning"
        })
    
    # GPU metrics if available
    if "gpu" in metrics:
        if "memory_percent" in metrics["gpu"] and metrics["gpu"]["memory_percent"] > thresholds["gpu_memory"]:
            anomalies.append({
                "type": "gpu_memory",
                "message": f"High GPU memory usage: {metrics['gpu']['memory_percent']:.1f}%",
                "value": metrics["gpu"]["memory_percent"],
                "threshold": thresholds["gpu_memory"],
                "severity": "critical" if metrics["gpu"]["memory_percent"] > thresholds["gpu_memory"] + 10 else "warning"
            })
        
        if "temperature" in metrics["gpu"] and metrics["gpu"]["temperature"] > thresholds["gpu_temp"]:
            anomalies.append({
                "type": "gpu_temperature",
                "message": f"High GPU temperature: {metrics['gpu']['temperature']}°C",
                "value": metrics["gpu"]["temperature"],
                "threshold": thresholds["gpu_temp"],
                "severity": "critical" if metrics["gpu"]["temperature"] > thresholds["gpu_temp"] + 5 else "warning"
            })
    
    return anomalies

def print_metrics_summary(metrics, trends, anomalies):
    """Print a nicely formatted summary of the metrics"""
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    print(f"\n{ColoredOutput.HEADER}{ColoredOutput.BOLD}====== VULKAN-DEV CONTAINER MONITOR ======{ColoredOutput.ENDC}")
    print(f"{ColoredOutput.CYAN}Timestamp: {now}{ColoredOutput.ENDC}")
    
    # Print any anomalies first
    if anomalies:
        print(f"\n{ColoredOutput.BOLD}{ColoredOutput.RED}⚠️ ANOMALIES DETECTED ⚠️{ColoredOutput.ENDC}")
        for anomaly in anomalies:
            severity_color = ColoredOutput.RED if anomaly["severity"] == "critical" else ColoredOutput.YELLOW
            print(f"{severity_color}• {anomaly['message']} (Threshold: {anomaly['threshold']}%){ColoredOutput.ENDC}")
    
    # CPU metrics
    cpu = metrics["cpu"]
    cpu_trend = trends.get("cpu", 0)
    trend_arrow = "↑" if cpu_trend > 2 else "↓" if cpu_trend < -2 else "→"
    trend_color = ColoredOutput.RED if cpu_trend > 5 else ColoredOutput.GREEN if cpu_trend < -2 else ColoredOutput.ENDC
    
    print(f"\n{ColoredOutput.BOLD}CPU:{ColoredOutput.ENDC}")
    print(f"  Overall: {cpu['overall_percent']:.1f}% {trend_color}{trend_arrow}{ColoredOutput.ENDC} " +
          f"({cpu['core_count']} cores / {cpu['thread_count']} threads)")
    
    if cpu['per_cpu_percent']:
        cpu_bars = ""
        for i, core in enumerate(cpu['per_cpu_percent']):
            color = ColoredOutput.RED if core > 80 else ColoredOutput.YELLOW if core > 50 else ColoredOutput.GREEN
            cpu_bars += f"{color}C{i}: {core:.0f}%{ColoredOutput.ENDC} "
            if (i + 1) % 4 == 0:
                cpu_bars += "\n  "
        print(f"  Per CPU: {cpu_bars}")
    
    # Memory metrics
    mem = metrics["memory"]
    mem_trend = trends.get("memory", 0)
    trend_arrow = "↑" if mem_trend > 2 else "↓" if mem_trend < -2 else "→"
    trend_color = ColoredOutput.RED if mem_trend > 5 else ColoredOutput.GREEN if mem_trend < -2 else ColoredOutput.ENDC
    
    print(f"\n{ColoredOutput.BOLD}Memory:{ColoredOutput.ENDC}")
    print(f"  RAM: {mem['used_gb']:.2f} GB / {mem['total_gb']:.2f} GB ({mem['percent']}% used) " +
          f"{trend_color}{trend_arrow}{ColoredOutput.ENDC}")
    print(f"  Swap: {mem['swap_used_gb']:.2f} GB / {mem['swap_total_gb']:.2f} GB ({mem['swap_percent']}% used)")
    
    # GPU metrics if available
    if "gpu" in metrics:
        gpu = metrics["gpu"]
        gpu_util_trend = trends.get("gpu_util", 0)
        gpu_mem_trend = trends.get("gpu_memory", 0)
        util_arrow = "↑" if gpu_util_trend > 2 else "↓" if gpu_util_trend < -2 else "→"
        mem_arrow = "↑" if gpu_mem_trend > 2 else "↓" if gpu_mem_trend < -2 else "→"
        
        print(f"\n{ColoredOutput.BOLD}GPU:{ColoredOutput.ENDC}")
        if "utilization" in gpu:
            util_color = ColoredOutput.RED if gpu["utilization"] > 85 else ColoredOutput.YELLOW if gpu["utilization"] > 50 else ColoredOutput.GREEN
            print(f"  Utilization: {util_color}{gpu['utilization']:.1f}%{ColoredOutput.ENDC} {util_arrow}")
            
        if "memory_used_mb" in gpu and "memory_total_mb" in gpu:
            mem_color = ColoredOutput.RED if gpu["memory_percent"] > 85 else ColoredOutput.YELLOW if gpu["memory_percent"] > 70 else ColoredOutput.GREEN
            print(f"  Memory: {mem_color}{gpu['memory_used_mb']:.0f} MB / {gpu['memory_total_mb']:.0f} MB ({gpu['memory_percent']:.1f}%){ColoredOutput.ENDC} {mem_arrow}")
            
        if "temperature" in gpu:
            temp_color = ColoredOutput.RED if gpu["temperature"] > 80 else ColoredOutput.YELLOW if gpu["temperature"] > 70 else ColoredOutput.GREEN
            print(f"  Temperature: {temp_color}{gpu['temperature']:.1f}°C{ColoredOutput.ENDC}")
    
    # Disk metrics
    disk = metrics["disk"]
    disk_read_trend = trends.get("disk_io_read_mb", 0)
    disk_write_trend = trends.get("disk_io_write_mb", 0)
    
    print(f"\n{ColoredOutput.BOLD}Disk:{ColoredOutput.ENDC}")
    disk_color = ColoredOutput.RED if disk["percent"] > 90 else ColoredOutput.YELLOW if disk["percent"] > 75 else ColoredOutput.GREEN
    print(f"  Usage: {disk_color}{disk['used_gb']:.2f} GB / {disk['total_gb']:.2f} GB ({disk['percent']}%){ColoredOutput.ENDC}")
    print(f"  I/O: {disk['read_mb']:.2f} MB read / {disk['write_mb']:.2f} MB written")
    
    # Network metrics
    net = metrics["network"]
    net_recv_trend = trends.get("net_io_recv_mb", 0)
    net_sent_trend = trends.get("net_io_sent_mb", 0)
    
    print(f"\n{ColoredOutput.BOLD}Network:{ColoredOutput.ENDC}")
    print(f"  Transfer: {net['bytes_recv_mb']:.2f} MB received / {net['bytes_sent_mb']:.2f} MB sent")
    print(f"  Packets: {net['packets_recv']} received / {net['packets_sent']} sent")
    if net['errin'] > 0 or net['errout'] > 0 or net['dropin'] > 0 or net['dropout'] > 0:
        print(f"  Errors: {net['errin']} in / {net['errout']} out, Dropped: {net['dropin']} in / {net['dropout']} out")
    
    # Top processes
    print(f"\n{ColoredOutput.BOLD}Top Processes:{ColoredOutput.ENDC}")
    for i, proc in enumerate(metrics["top_processes"]):
        if i < 3:  # Only show top 3
            print(f"  {proc['name']} (PID {proc['pid']}): CPU {proc['cpu_percent']:.1f}%, Mem {proc['memory_percent']:.1f}%")
    
    # Vulkan information if available
    vulkan_info = get_vulkan_info()
    if vulkan_info and 'api_version' in vulkan_info:
        print(f"\n{ColoredOutput.BOLD}Vulkan:{ColoredOutput.ENDC}")
        print(f"  API Version: {vulkan_info['api_version']}")
        if 'devices' in vulkan_info:
            for device in vulkan_info['devices']:
                print(f"  Device {device['id']}: {device['name']}")
    
    print(f"\n{ColoredOutput.CYAN}Next update in {CONFIG['log_interval']} seconds...{ColoredOutput.ENDC}")

def log_to_file(metrics, trends, anomalies, filename="vulkan_container_metrics.log"):
    """Log metrics to a file in JSON format for later analysis"""
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "metrics": metrics,
        "trends": trends,
        "anomalies": anomalies
    }
    
    try:
        with open(filename, "a") as f:
            f.write(json.dumps(log_entry) + "\n")
    except Exception as e:
        print(f"Error writing to log file: {e}")

def print_banner():
    """Print an ASCII art banner"""
    banner = """
        ╦  ╦╦ ╦╦  ╦╔═╔═╗╔╗╔   ╔╦ ╔═╗╦  ╦
        ╚╗╔╝║ ║║  ║╔╝╠═╣║║║ ─ ║║ ║╣ ╚╗╔╝
        ╚╝ ╚═╝╩═╝╩╚═╩ ╩╝╚╝   ╩╩ ╚═╝ ╚╝ 
        Advanced Container Monitor v1.0
    """
    print(f"{ColoredOutput.CYAN}{banner}{ColoredOutput.ENDC}")

def main():
    """Main function to run the monitoring system"""
    # Set up signal handler for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    
    # Print banner and container info
    print_banner()
    container_info = get_container_info()
    
    print(f"{ColoredOutput.BOLD}Container Information:{ColoredOutput.ENDC}")
    print(f"  Name: {container_info['name']}")
    print(f"  Hostname: {container_info['hostname']}")
    
    print(f"\n{ColoredOutput.BOLD}Development Environment:{ColoredOutput.ENDC}")
    env_vars = container_info['environment_vars']
    for key, value in env_vars.items():
        if value != 'N/A':
            print(f"  {key}: {value}")
    
    # Start GPU metrics collection thread
    gpu_thread = threading.Thread(target=collect_gpu_metrics, daemon=True)
    gpu_thread.start()
    
    print(f"\n{ColoredOutput.GREEN}Starting advanced monitoring system...{ColoredOutput.ENDC}")
    
    # Main monitoring loop
    log_count = 0
    while True:
        try:
            # Get system metrics
            metrics = get_system_metrics()
            
            # Calculate trends
            trends = calculate_trends(history)
            
            # Detect anomalies
            anomalies = detect_anomalies(metrics, CONFIG["alert_thresholds"])
            
            # Print summary
            print_metrics_summary(metrics, trends, anomalies)
            
            # Log to file every 10 iterations
            log_count += 1
            if log_count % 10 == 0:
                log_to_file(metrics, trends, anomalies)
            
            # Wait for next iteration
            time.sleep(CONFIG["log_interval"])
            
        except Exception as e:
            print(f"Error in monitoring loop: {e}")
            time.sleep(5)

if __name__ == "__main__":
    main()