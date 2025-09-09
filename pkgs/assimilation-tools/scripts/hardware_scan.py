#!/usr/bin/env python3
"""
Hardware Scanning Tool for Starfleet OS

This tool scans hardware and reports information about the system.
It can be used to identify potential targets for assimilation.
"""

import os
import sys
import argparse
import subprocess
import json
import platform
import datetime

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Hardware Scanning Tool")
    parser.add_argument("--output", "-o", help="Output file for scan results")
    parser.add_argument("--format", "-f", choices=["json", "yaml", "text"], 
                        default="text", help="Output format")
    parser.add_argument("--scan", "-s", choices=["full", "quick", "network", "usb", "pci"],
                        default="quick", help="Scan type")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    return parser.parse_args()

def get_system_info():
    """Get basic system information"""
    info = {
        "hostname": platform.node(),
        "platform": platform.platform(),
        "processor": platform.processor(),
        "architecture": platform.machine(),
        "python_version": platform.python_version(),
        "timestamp": datetime.datetime.now().isoformat()
    }
    
    # Get kernel version
    try:
        info["kernel"] = subprocess.check_output(["uname", "-r"], 
                                               universal_newlines=True).strip()
    except subprocess.SubprocessError:
        info["kernel"] = "unknown"
    
    # Get memory info
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    info["memory_total"] = line.split()[1]
                elif line.startswith("MemFree:"):
                    info["memory_free"] = line.split()[1]
    except FileNotFoundError:
        info["memory_total"] = "unknown"
        info["memory_free"] = "unknown"
    
    return info

def scan_usb_devices():
    """Scan USB devices"""
    try:
        output = subprocess.check_output(["lsusb"], universal_newlines=True)
        devices = []
        for line in output.splitlines():
            if line.strip():
                devices.append(line)
        return devices
    except subprocess.SubprocessError:
        return ["Error: Could not scan USB devices"]

def scan_pci_devices():
    """Scan PCI devices"""
    try:
        output = subprocess.check_output(["lspci"], universal_newlines=True)
        devices = []
        for line in output.splitlines():
            if line.strip():
                devices.append(line)
        return devices
    except subprocess.SubprocessError:
        return ["Error: Could not scan PCI devices"]

def scan_network():
    """Scan network interfaces"""
    try:
        output = subprocess.check_output(["ip", "addr"], universal_newlines=True)
        interfaces = []
        current_if = None
        for line in output.splitlines():
            if line.startswith(" "):
                if current_if is not None:
                    interfaces[-1]["details"].append(line.strip())
            else:
                parts = line.split(":", 2)
                if len(parts) >= 2:
                    current_if = parts[1].strip()
                    interfaces.append({"name": current_if, "details": []})
        return interfaces
    except subprocess.SubprocessError:
        return [{"name": "Error", "details": ["Could not scan network interfaces"]}]

def scan_hardware(scan_type):
    """Scan hardware based on scan type"""
    results = {
        "system_info": get_system_info()
    }
    
    if scan_type in ["full", "quick", "usb"]:
        results["usb_devices"] = scan_usb_devices()
    
    if scan_type in ["full", "quick", "pci"]:
        results["pci_devices"] = scan_pci_devices()
    
    if scan_type in ["full", "network"]:
        results["network"] = scan_network()
    
    if scan_type == "full":
        # Run additional commands for full scan
        try:
            results["dmi_info"] = subprocess.check_output(
                ["dmidecode"], universal_newlines=True)
        except subprocess.SubprocessError:
            results["dmi_info"] = "Error: Could not get DMI information"
        
        try:
            results["lshw"] = subprocess.check_output(
                ["lshw", "-short"], universal_newlines=True)
        except subprocess.SubprocessError:
            results["lshw"] = "Error: Could not get hardware information"
    
    return results

def format_output(results, format_type):
    """Format scan results based on format type"""
    if format_type == "json":
        return json.dumps(results, indent=2)
    elif format_type == "yaml":
        try:
            import yaml
            return yaml.dump(results, default_flow_style=False)
        except ImportError:
            print("Error: PyYAML not installed. Falling back to JSON format.")
            return json.dumps(results, indent=2)
    else:  # text format
        output = []
        output.append("=== System Information ===")
        for key, value in results["system_info"].items():
            output.append(f"{key}: {value}")
        
        if "usb_devices" in results:
            output.append("\n=== USB Devices ===")
            for device in results["usb_devices"]:
                output.append(device)
        
        if "pci_devices" in results:
            output.append("\n=== PCI Devices ===")
            for device in results["pci_devices"]:
                output.append(device)
        
        if "network" in results:
            output.append("\n=== Network Interfaces ===")
            for interface in results["network"]:
                output.append(f"Interface: {interface['name']}")
                for detail in interface["details"]:
                    output.append(f"  {detail}")
        
        if "dmi_info" in results:
            output.append("\n=== DMI Information ===")
            output.append(results["dmi_info"])
        
        if "lshw" in results:
            output.append("\n=== Hardware Information ===")
            output.append(results["lshw"])
        
        return "\n".join(output)

def main():
    """Main function"""
    args = parse_args()
    
    print("Scanning hardware...")
    results = scan_hardware(args.scan)
    
    output = format_output(results, args.format)
    
    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
        print(f"Scan results written to {args.output}")
    else:
        print(output)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())