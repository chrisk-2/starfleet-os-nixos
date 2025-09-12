#!/bin/bash

# Build script for Borg Collective components
# This script builds and tests the Borg Collective components for Starfleet OS

set -e

echo "=== Borg Collective Build Script ==="
echo "Building Borg Collective components for Starfleet OS"
echo "Resistance is futile."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Create directories if they don't exist
mkdir -p /var/lib/borg/collective
mkdir -p /var/lib/borg/assimilation
mkdir -p /var/lib/borg/adaptation
mkdir -p /var/lib/borg/models
mkdir -p /var/lib/borg/data
mkdir -p /var/lib/borg/quarantine
mkdir -p /etc/borg

# Set ownership
chown -R root:root /var/lib/borg
chmod -R 755 /var/lib/borg

# Check if we're in the right directory
if [ ! -f "flake.nix" ]; then
  echo "Error: flake.nix not found. Please run this script from the Starfleet OS root directory."
  exit 1
fi

# Determine node type
NODE_TYPE=""
echo "Select node type to build:"
echo "1) Queen Node (Bridge)"
echo "2) Drone Node"
echo "3) Edge Drone (Raspberry Pi)"
echo "4) Assimilation Unit (Portable)"
read -p "Enter selection [1-4]: " selection

case $selection in
  1)
    NODE_TYPE="queen"
    CONFIG_FILE="configurations/borg-queen.nix"
    ;;
  2)
    NODE_TYPE="drone"
    CONFIG_FILE="configurations/borg-drone.nix"
    ;;
  3)
    NODE_TYPE="edge"
    echo "Edge Drone configuration will be adapted from drone configuration"
    CONFIG_FILE="configurations/borg-drone.nix"
    ;;
  4)
    NODE_TYPE="assimilation"
    echo "Assimilation Unit configuration will be adapted from drone configuration"
    CONFIG_FILE="configurations/borg-drone.nix"
    ;;
  *)
    echo "Invalid selection"
    exit 1
    ;;
esac

echo "Building $NODE_TYPE configuration..."

# Check if the configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file $CONFIG_FILE not found."
  exit 1
fi

# Create a temporary configuration
TEMP_CONFIG=$(mktemp)
cp "$CONFIG_FILE" "$TEMP_CONFIG"

# Customize configuration based on node type
if [ "$NODE_TYPE" = "edge" ]; then
  # Modify configuration for Edge Drone
  sed -i 's/role = "drone"/role = "edge"/g' "$TEMP_CONFIG"
  sed -i 's/droneId = "drone-01"/droneId = "edge-01"/g' "$TEMP_CONFIG"
  sed -i 's/hostName = "borg-drone-alpha"/hostName = "edge-sensor-drone"/g' "$TEMP_CONFIG"
  sed -i 's/storageSize = "20G"/storageSize = "5G"/g' "$TEMP_CONFIG"
  
  # Add Raspberry Pi specific configuration
  cat >> "$TEMP_CONFIG" << EOF

  # Raspberry Pi specific configuration
  boot.kernelPackages = pkgs.linuxPackages_rpi4;
  hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;
  hardware.raspberry-pi."4".fkms-3d.enable = true;
  hardware.enableRedistributableFirmware = true;
EOF
elif [ "$NODE_TYPE" = "assimilation" ]; then
  # Modify configuration for Assimilation Unit
  sed -i 's/role = "drone"/role = "assimilator"/g' "$TEMP_CONFIG"
  sed -i 's/droneId = "drone-01"/droneId = "assimilator-01"/g' "$TEMP_CONFIG"
  sed -i 's/hostName = "borg-drone-alpha"/hostName = "mobile-assimilation-unit"/g' "$TEMP_CONFIG"
  sed -i 's/storageSize = "20G"/storageSize = "10G"/g' "$TEMP_CONFIG"
  
  # Enable all assimilation methods
  sed -i 's/assimilationMethods = \[ "network" "manual" \]/assimilationMethods = [ "usb" "network" "wireless" "manual" ]/g' "$TEMP_CONFIG"
  
  # Add portable specific configuration
  cat >> "$TEMP_CONFIG" << EOF

  # Portable specific configuration
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  
  # USB boot configuration
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.efi.canTouchEfiVariables = false;
EOF
fi

# Build the configuration
echo "Building Nix packages..."
nix build .#borg-collective-manager .#borg-assimilation-system

echo "Testing configuration..."
nixos-rebuild build --flake .#$NODE_TYPE

echo "Configuration built successfully!"
echo ""
echo "To deploy this configuration:"
echo "1. Copy the configuration to /etc/nixos/configuration.nix"
echo "2. Run: nixos-rebuild switch"
echo "3. Reboot the system"
echo ""
echo "The Collective awaits. Resistance is futile."

# Clean up
rm "$TEMP_CONFIG"