#!/usr/bin/env python3
import time
import psutil
import os
import subprocess as sp
from datetime import datetime
import signal
import sys
import re
from collections import deque

# Force terminal colors if not set in the container
if not os.environ.get('TERM'):
    os.environ['TERM'] = 'xterm-256color'

# Configuration
CONFIG = {
    "container_name": "VULKAN-DEV",
    "log_interval": 60,
    "history_size": 15,
    "alert_thresholds": {
        "cpu": 85, "memory": 85, "gpu_memory": 85, "gpu_temp": 80, "disk": 90,
    }
}

# Advanced historical tracking & state
history = {
    "cpu": deque([0]*CONFIG["history_size"], maxlen=CONFIG["history_size"]),
    "memory": deque([0]*CONFIG["history_size"], maxlen=CONFIG["history_size"]),
    "gpu_util": deque([0]*CONFIG["history_size"], maxlen=CONFIG["history_size"]),
    "gpu_memory": deque([0]*CONFIG["history_size"], maxlen=CONFIG["history_size"]),
}

# Store previous network/disk states to calculate speed/deltas
last_net = {"recv": 0, "sent": 0, "time": time.time()}
last_disk = {"read": 0, "write": 0, "time": time.time()}

class UI:
    """Terminal aesthetics and ANSI codes"""
    PURPLE = '\033[38;5;135m'
    BLUE = '\033[38;5;39m'
    CYAN = '\033[38;5;51m'
    GREEN = '\033[38;5;46m'
    YELLOW = '\033[38;5;226m'
    ORANGE = '\033[38;5;208m'
    RED = '\033[38;5;196m'
    GREY = '\033[38;5;240m'
    WHITE = '\033[38;5;255m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    
    # Box drawing characters
    TL = '╔' ; TR = '╗' ; BL = '╚' ; BR = '╝'
    H = '═' ; V = '║'
    L_T = '╠' ; R_T = '╣' ; T_T = '╦' ; B_T = '╩' ; CROSS = '╬'

def generate_sparkline(data, max_val=100):
    bars = '  ▂▃▄▅▆▇█'
    if not data or all(x == 0 for x in data):
        return f"{UI.GREY}{bars[0] * len(data)}{UI.ENDC}"
    
    sparkline = ""
    for val in data:
        if val is None: val = 0
        ratio = min(max(val / max_val, 0), 1)
        bar_idx = int(ratio * (len(bars) - 1))
        
        color = UI.GREEN
        if ratio > 0.85: color = UI.RED
        elif ratio > 0.60: color = UI.ORANGE
        elif ratio > 0.40: color = UI.YELLOW
        
        sparkline += f"{color}{bars[bar_idx]}{UI.ENDC}"
    return sparkline

def predictive_analysis(data_list, metric_name, threshold):
    if len(data_list) < 5 or all(x == 0 for x in data_list):
        return ""
    
    x = list(range(len(data_list)))
    y = list(data_list)
    n = len(x)
    
    sum_x = sum(x)
    sum_y = sum(y)
    sum_xy = sum(i*j for i,j in zip(x, y))
    sum_xx = sum(i**2 for i in x)
    
    denominator = (n * sum_xx - sum_x**2)
    if denominator == 0: return f"{UI.GREY}Stable trajectory{UI.ENDC}"
    
    slope = (n * sum_xy - sum_x * sum_y) / denominator
    
    if slope > 1.5:
        minutes_to_critical = max(0, (threshold - y[-1]) / slope) if slope > 0 else 0
        if minutes_to_critical < 15 and y[-1] > 50:
            return f"{UI.RED}▲ Warning: Predicting critical {metric_name} in ~{int(minutes_to_critical)} mins{UI.ENDC}"
        return f"{UI.ORANGE}▲ Trending Upwards (+{slope:.1f}%/min){UI.ENDC}"
    elif slope < -1.5:
        return f"{UI.GREEN}▼ Trending Downwards ({slope:.1f}%/min){UI.ENDC}"
    return f"{UI.CYAN}► Stable trajectory{UI.ENDC}"

def generate_progress_bar(percent, width=30):
    filled_width = int((percent / 100) * width)
    empty_width = width - filled_width
    
    color = UI.GREEN
    if percent > 85: color = UI.RED
    elif percent > 70: color = UI.ORANGE
    elif percent > 50: color = UI.YELLOW
    
    return f"{color}{'█' * filled_width}{UI.ENDC}{UI.GREY}{'░' * empty_width}{UI.ENDC}"

def format_bytes(bytes_val):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_val < 1024.0:
            return f"{bytes_val:5.1f} {unit}"
        bytes_val /= 1024.0

def signal_handler(sig, frame):
    print(f"\n{UI.YELLOW}Terminating Dev Monitor...{UI.ENDC}")
    sys.exit(0)

def get_vulkan_info():
    vulkan_info = {}
    try:
        result = sp.run("vulkaninfo --summary", shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            version_match = re.search(r'Vulkan API Version: (\d+\.\d+\.\d+)', result.stdout)
            if version_match: vulkan_info['api_version'] = version_match.group(1)
            device_matches = re.findall(r'GPU(\d+): (.*?)\n', result.stdout)
            vulkan_info['devices'] = [{'id': m[0], 'name': m[1].strip()} for m in device_matches]
    except:
        pass
    return vulkan_info

def get_system_metrics():
    global last_net, last_disk
    metrics = {}
    current_time = time.time()
    
    # System Info
    try:
        load1, load5, load15 = os.getloadavg()
    except AttributeError:
        load1, load5, load15 = 0.0, 0.0, 0.0
    
    boot_time = datetime.fromtimestamp(psutil.boot_time())
    uptime = datetime.now() - boot_time
    
    metrics["system"] = {
        "load": (load1, load5, load15),
        "uptime": str(uptime).split('.')[0]
    }

    # CPU
    overall_cpu = psutil.cpu_percent(interval=0.5)
    metrics["cpu"] = {
        "overall_percent": overall_cpu,
        "core_count": psutil.cpu_count(logical=False),
        "thread_count": psutil.cpu_count(logical=True),
    }
    history["cpu"].append(overall_cpu)
    
    # Memory & Swap
    memory = psutil.virtual_memory()
    swap = psutil.swap_memory()
    metrics["memory"] = {
        "total_gb": memory.total / (1024**3),
        "used_gb": memory.used / (1024**3),
        "percent": memory.percent,
        "swap_percent": swap.percent,
        "swap_used_gb": swap.used / (1024**3)
    }
    history["memory"].append(memory.percent)
  
    gpu_metrics = {
        "available": False,
        "status": "INITIALIZING",
        "utilization": 0.0,
        "memory_used_mb": 0.0,
        "memory_total_mb": 0.0,
        "memory_percent": 0.0,
        "temperature": 0.0
    }
    
    try:
        # Use a slightly longer timeout for the first run, then 2s for subsequent
        result = sp.run(
            "nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits", 
            shell=True, capture_output=True, text=True, timeout=3
        )
        
        if result.returncode == 0 and result.stdout.strip():
            gpu_data = result.stdout.strip().split(',')
            if len(gpu_data) >= 4:
                gpu_metrics.update({
                    "available": True,
                    "status": "OPERATIONAL",
                    "utilization": float(gpu_data[0].strip()),
                    "memory_used_mb": float(gpu_data[1].strip()),
                    "memory_total_mb": float(gpu_data[2].strip()),
                    "memory_percent": (float(gpu_data[1].strip()) / float(gpu_data[2].strip())) * 100 if float(gpu_data[2].strip()) > 0 else 0,
                    "temperature": float(gpu_data[3].strip())
                })
        else:
            # Check for common NVIDIA errors in stderr
            error_msg = result.stderr.lower()
            if "mismatch" in error_msg:
                gpu_metrics["status"] = "VER_MISMATCH"
            elif "initialized" in error_msg or "communication" in error_msg:
                gpu_metrics["status"] = "DRIVER_ERROR"
            else:
                gpu_metrics["status"] = "OFFLINE"

    except sp.TimeoutExpired:
        gpu_metrics["status"] = "TIMEOUT"
    except FileNotFoundError:
        gpu_metrics["status"] = "SMI_MISSING"
    except Exception as e:
        gpu_metrics["status"] = "UNKNOWN_ERR"
        
    metrics["gpu"] = gpu_metrics
    # Only append to history if valid data exists, else append last known or 0
    history["gpu_util"].append(gpu_metrics["utilization"])
    history["gpu_memory"].append(gpu_metrics["memory_percent"])
        
    # Disk & Net (with speed calculations)
    disk_usage = psutil.disk_usage('/')
    disk_io = psutil.disk_io_counters()
    net_io = psutil.net_io_counters()
    
    time_delta = current_time - last_disk["time"]
    read_speed = (disk_io.read_bytes - last_disk["read"]) / time_delta if time_delta > 0 else 0
    write_speed = (disk_io.write_bytes - last_disk["write"]) / time_delta if time_delta > 0 else 0
    
    last_disk = {"read": disk_io.read_bytes, "write": disk_io.write_bytes, "time": current_time}
    
    metrics["disk"] = {
        "percent": disk_usage.percent, 
        "total_gb": disk_usage.total / (1024**3), 
        "used_gb": disk_usage.used / (1024**3),
        "read_speed": read_speed,
        "write_speed": write_speed,
        "read_total": disk_io.read_bytes,
        "write_total": disk_io.write_bytes
    }
    
    recv_speed = (net_io.bytes_recv - last_net["recv"]) / time_delta if time_delta > 0 else 0
    sent_speed = (net_io.bytes_sent - last_net["sent"]) / time_delta if time_delta > 0 else 0
    
    last_net = {"recv": net_io.bytes_recv, "sent": net_io.bytes_sent, "time": current_time}
    
    metrics["network"] = {
        "recv_total": net_io.bytes_recv,
        "sent_total": net_io.bytes_sent,
        "recv_speed": recv_speed,
        "sent_speed": sent_speed,
        "packets": f"{net_io.packets_recv} RX / {net_io.packets_sent} TX"
    }
    
    # Process Analysis (Expanded Categorization)
    processes = []
    for proc in sorted(psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent', 'cmdline']), 
                       key=lambda p: p.info['cpu_percent'] + p.info['memory_percent'], 
                       reverse=True)[:7]:
        try:
            cat = "SYSTEM"
            name = proc.info['name'].lower()
            cmdline = " ".join(proc.info.get('cmdline', [])).lower()
            full_check = name + " " + cmdline
            
            if any(x in full_check for x in ['g++', 'clang', 'cmake', 'make', 'ninja', 'gcc', 'ld']): cat = "BUILD"
            elif any(x in full_check for x in ['python', 'jupyter', 'qmemscanner']): cat = "SCRIPT/AI"
            elif any(x in full_check for x in ['qt', 'qml', 'vulkan', 'gl', 'wayland', 'xorg']): cat = "ENGINE/GUI"
            elif any(x in full_check for x in ['postgres', 'pg_']): cat = "DATABASE"
            elif any(x in full_check for x in ['docker', 'containerd']): cat = "CONTAINER"
            elif any(x in full_check for x in ['pacman', 'yay']): cat = "PKG_MGR"
            
            processes.append({
                "pid": proc.info['pid'],
                "name": proc.info['name'],
                "cpu_percent": proc.info['cpu_percent'],
                "memory_percent": proc.info['memory_percent'],
                "category": cat
            })
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    metrics["top_processes"] = processes
    return metrics

def print_dashboard(metrics):
    os.system('clear' if os.name == 'posix' else 'cls')
    now = datetime.now().strftime("%H:%M:%S")
    vulkan = get_vulkan_info()
    
    print(f"{UI.PURPLE}{UI.TL}{UI.H*70}{UI.TR}{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} {UI.BOLD}{UI.CYAN}⚡ VULKAN-DEV TELEMETRY DASHBOARD ⚡{UI.ENDC}".ljust(79) + f"{UI.PURPLE}{UI.V}{UI.ENDC}")
    
    # 0. SYSTEM OVERVIEW
    sys_info = metrics["system"]
    print(f"{UI.PURPLE}{UI.L_T}{UI.H*70}{UI.R_T}{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} {UI.BOLD}SYSTEM STATE{UI.ENDC} [{now}]")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Uptime:    {sys_info['uptime']}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Load Avg:  {sys_info['load'][0]:.2f} (1m) | {sys_info['load'][1]:.2f} (5m) | {sys_info['load'][2]:.2f} (15m)")
    
    if vulkan.get('api_version'):
        print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Vulkan API: {vulkan['api_version']} | Devices: {len(vulkan.get('devices', []))}")

    # 1. CORE COMPUTE
    cpu = metrics["cpu"]
    cpu_pred = predictive_analysis(history["cpu"], "CPU", CONFIG["alert_thresholds"]["cpu"])
    print(f"{UI.PURPLE}{UI.L_T}{UI.H*70}{UI.R_T}{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} {UI.BOLD}CORE COMPUTE{UI.ENDC} ({cpu['core_count']} Physical / {cpu['thread_count']} Logical)")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} CPU Load:  {generate_progress_bar(cpu['overall_percent'], 25)} {cpu['overall_percent']:>5.1f}%")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} History:   [{generate_sparkline(history['cpu'])}] {cpu_pred}")
    
    # 2. MEMORY SUBSYSTEM
    mem = metrics["memory"]
    mem_pred = predictive_analysis(history["memory"], "RAM", CONFIG["alert_thresholds"]["memory"])
    print(f"{UI.PURPLE}{UI.L_T}{UI.H*70}{UI.R_T}{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} {UI.BOLD}MEMORY SUBSYSTEM{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} RAM Usage: {generate_progress_bar(mem['percent'], 25)} {mem['percent']:>5.1f}%")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} History:   [{generate_sparkline(history['memory'])}] {mem_pred}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} RAM Cap:   {UI.CYAN}{mem['used_gb']:.2f} GB / {mem['total_gb']:.2f} GB{UI.ENDC}")
    if mem['swap_used_gb'] > 0:
        print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Swap Use:  {UI.ORANGE}{mem['swap_used_gb']:.2f} GB ({mem['swap_percent']}%) - Watch for paging!{UI.ENDC}")

    # 3. GRAPHICS SUBSYSTEM
    gpu = metrics["gpu"]
    print(f"{UI.PURPLE}{UI.L_T}{UI.H*70}{UI.R_T}{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} {UI.BOLD}GRAPHICS SUBSYSTEM{UI.ENDC}")
    
    if gpu["available"]:
        gpu_pred = predictive_analysis(history["gpu_memory"], "VRAM", CONFIG["alert_thresholds"]["gpu_memory"])
        print(f"{UI.PURPLE}{UI.V}{UI.ENDC} GPU Core:  {generate_progress_bar(gpu['utilization'], 25)} {gpu['utilization']:>5.1f}%")
        print(f"{UI.PURPLE}{UI.V}{UI.ENDC} VRAM Use:  {generate_progress_bar(gpu['memory_percent'], 25)} {gpu['memory_percent']:>5.1f}%")
        print(f"{UI.PURPLE}{UI.V}{UI.ENDC} VRAM Cap:  {UI.CYAN}{gpu['memory_used_mb']:.0f} MB / {gpu['memory_total_mb']:.0f} MB{UI.ENDC}")
        print(f"{UI.PURPLE}{UI.V}{UI.ENDC} History:   [{generate_sparkline(history['gpu_memory'])}] {gpu_pred}")
        
        temp_color = UI.RED if gpu['temperature'] > 80 else UI.GREEN
        print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Temp:      {temp_color}{gpu['temperature']}°C{UI.ENDC}")
    else:
        # Dynamic error messaging based on the status code we set in get_system_metrics
        status = gpu.get("status", "OFFLINE")
        status_color = UI.RED if status in ["VER_MISMATCH", "DRIVER_ERROR"] else UI.GREY
        
        print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Status:    {status_color}[{status}]{UI.ENDC}")
        
        if status == "VER_MISMATCH":
            print(f"{UI.PURPLE}{UI.V}{UI.ENDC} {UI.YELLOW}⚠ Kernel/Library mismatch detected. Reboot required.{UI.ENDC}")
        elif status == "SMI_MISSING":
            print(f"{UI.PURPLE}{UI.V}{UI.ENDC} {UI.GREY}Command 'nvidia-smi' not found in path.{UI.ENDC}")
        else:
            print(f"{UI.PURPLE}{UI.V}{UI.ENDC} GPU Core:  {UI.GREY}No active NVIDIA device found.{UI.ENDC}")
            
        print(f"{UI.PURPLE}{UI.V}{UI.ENDC} VRAM:      {UI.GREY}N/A{UI.ENDC}")
        print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Temp:      {UI.GREY}N/A{UI.ENDC}")

    # 4. STORAGE & I/O
    disk = metrics["disk"]
    print(f"{UI.PURPLE}{UI.L_T}{UI.H*70}{UI.R_T}{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} {UI.BOLD}STORAGE & I/O{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Root Disk: {generate_progress_bar(disk['percent'], 25)} {disk['percent']:>5.1f}%")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Space:     {UI.CYAN}{disk['used_gb']:.1f} GB / {disk['total_gb']:.1f} GB{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Speed:     ▼ {format_bytes(disk['read_speed'])}/s  |  ▲ {format_bytes(disk['write_speed'])}/s")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Total I/O: {format_bytes(disk['read_total'])} Read | {format_bytes(disk['write_total'])} Written")

    # 5. NETWORK TELEMETRY
    net = metrics["network"]
    print(f"{UI.PURPLE}{UI.L_T}{UI.H*70}{UI.R_T}{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} {UI.BOLD}NETWORK TELEMETRY{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Throughput:▼ {format_bytes(net['recv_speed'])}/s  |  ▲ {format_bytes(net['sent_speed'])}/s")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Total Data: {format_bytes(net['recv_total'])} RX   | {format_bytes(net['sent_total'])} TX")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} Packets:    {net['packets']}")

    # 6. HEAVY PROCESSES
    print(f"{UI.PURPLE}{UI.L_T}{UI.H*70}{UI.R_T}{UI.ENDC}")
    print(f"{UI.PURPLE}{UI.V}{UI.ENDC} {UI.BOLD}ACTIVE PROCESS HEURISTICS (TOP 7){UI.ENDC}")
    for proc in metrics.get("top_processes", []):
        cat_color = {
            "BUILD": UI.ORANGE, 
            "SCRIPT/AI": UI.BLUE, 
            "ENGINE/GUI": UI.CYAN,
            "DATABASE": UI.YELLOW,
            "CONTAINER": UI.PURPLE,
            "PKG_MGR": UI.WHITE
        }.get(proc["category"], UI.GREEN)
        
        line = f" {cat_color}[{proc['category']:<10}]{UI.ENDC} {proc['name'][:18]:<18} | CPU: {proc['cpu_percent']:>4.1f}% | RAM: {proc['memory_percent']:>4.1f}%"
        print(f"{UI.PURPLE}{UI.V}{UI.ENDC}{line}")

    print(f"{UI.PURPLE}{UI.BL}{UI.H*70}{UI.BR}{UI.ENDC}\n")

def main():
    signal.signal(signal.SIGINT, signal_handler)
    
    print(f"{UI.GREEN}Initializing Telemetry... Gathering baseline history and I/O speeds.{UI.ENDC}")
    
    # Do an initial throwaway poll to set the baseline for network and disk speeds
    get_system_metrics()
    time.sleep(2) 
    
    while True:
        try:
            metrics = get_system_metrics()
            print_dashboard(metrics)
            time.sleep(CONFIG["log_interval"])
        except Exception as e:
            print(f"{UI.RED}Error in telemetry loop: {e}{UI.ENDC}")
            time.sleep(5)

if __name__ == "__main__":
    main()