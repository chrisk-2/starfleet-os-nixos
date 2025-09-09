#!/usr/bin/env python3
"""
USB Assimilation Tool for Starfleet OS

This tool is used to assimilate USB devices into the Borg Collective.
It can clone, modify, and create bootable USB devices with Starfleet OS.
"""

import os
import sys
import argparse
import subprocess
import yaml
import time

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="USB Assimilation Tool")
    parser.add_argument("--device", "-d", help="USB device to assimilate (e.g., /dev/sdb)")
    parser.add_argument("--mode", "-m", choices=["clone", "install", "ventoy"], 
                        default="install", help="Assimilation mode")
    parser.add_argument("--iso", "-i", help="ISO file to use for installation")
    parser.add_argument("--config", "-c", help="Configuration file for customization")
    parser.add_argument("--force", "-f", action="store_true", help="Force operation without confirmation")
    return parser.parse_args()

def check_device(device):
    """Check if device exists and is a USB device"""
    if not os.path.exists(device):
        print(f"Error: Device {device} does not exist")
        return False
    
    # Check if it's a removable device
    try:
        with open(f"/sys/block/{os.path.basename(device)}/removable", "r") as f:
            if f.read().strip() != "1":
                print(f"Warning: {device} does not appear to be a removable device")
                return False
    except FileNotFoundError:
        print(f"Error: Could not determine if {device} is removable")
        return False
    
    return True

def confirm_operation(device):
    """Ask for confirmation before proceeding"""
    print(f"WARNING: This will erase all data on {device}")
    response = input("Are you sure you want to continue? (yes/no): ")
    return response.lower() in ["yes", "y"]

def clone_usb(source, target):
    """Clone a USB device to another"""
    print(f"Cloning {source} to {target}...")
    subprocess.run(["dd", "if=" + source, "of=" + target, "bs=4M", "status=progress"])
    print("Clone complete")

def install_iso(iso, device):
    """Install an ISO to a USB device"""
    print(f"Installing {iso} to {device}...")
    subprocess.run(["dd", "if=" + iso, "of=" + device, "bs=4M", "status=progress"])
    print("Installation complete")

def setup_ventoy(device):
    """Set up Ventoy on a USB device"""
    print(f"Setting up Ventoy on {device}...")
    ventoy_path = "/usr/share/assimilation-tools/ventoy"
    subprocess.run([f"{ventoy_path}/Ventoy2Disk.sh", "-i", device])
    print("Ventoy setup complete")

def main():
    """Main function"""
    args = parse_args()
    
    if not args.device:
        print("Error: No device specified")
        return 1
    
    if not check_device(args.device):
        return 1
    
    if not args.force and not confirm_operation(args.device):
        print("Operation cancelled")
        return 0
    
    if args.mode == "clone":
        if not args.iso:
            print("Error: Source device not specified for clone mode")
            return 1
        clone_usb(args.iso, args.device)
    elif args.mode == "install":
        if not args.iso:
            print("Error: ISO file not specified for install mode")
            return 1
        install_iso(args.iso, args.device)
    elif args.mode == "ventoy":
        setup_ventoy(args.device)
    
    print("USB assimilation complete")
    return 0

if __name__ == "__main__":
    sys.exit(main())