#!/bin/bash

# Starfleet OS Build Test Script
# This script builds and tests the Starfleet OS implementation

set -e

echo "===== Starfleet OS Build Test ====="
echo "Date: $(date)"
echo "===== Environment Information ====="
echo "Nix Version: $(nix --version)"
echo "System: $(uname -a)"
echo "===== Starting Build Process ====="

# Create build directory
BUILD_DIR="build/test"
mkdir -p $BUILD_DIR

# Function to log with timestamp
log() {
  echo "[$(date +%H:%M:%S)] $1"
}

# Function to check if a command exists
check_command() {
  if ! command -v $1 &> /dev/null; then
    log "Error: $1 is not installed"
    exit 1
  fi
}

# Check required commands
check_command nix
check_command git

# Clone repository if not already done
if [ ! -d ".git" ]; then
  log "Cloning repository..."
  git init
  git remote add origin https://github.com/chrisk-2/starfleet-os-nixos.git
  git fetch
  git checkout -b main origin/main
fi

# Update repository
log "Updating repository..."
git pull origin main

# Check flake.nix
log "Checking flake.nix..."
if [ ! -f "flake.nix" ]; then
  log "Error: flake.nix not found"
  exit 1
fi

# Validate flake
log "Validating flake..."
nix flake check

# Build bridge configuration
log "Building bridge configuration..."
nix build .#nixosConfigurations.bridge.config.system.build.toplevel -o $BUILD_DIR/bridge

# Build drone-a configuration
log "Building drone-a configuration..."
nix build .#nixosConfigurations.drone-a.config.system.build.toplevel -o $BUILD_DIR/drone-a

# Build drone-b configuration
log "Building drone-b configuration..."
nix build .#nixosConfigurations.drone-b.config.system.build.toplevel -o $BUILD_DIR/drone-b

# Build edge-pi configuration
log "Building edge-pi configuration..."
nix build .#nixosConfigurations.edge-pi.config.system.build.toplevel -o $BUILD_DIR/edge-pi

# Build portable configuration
log "Building portable configuration..."
nix build .#nixosConfigurations.portable.config.system.build.toplevel -o $BUILD_DIR/portable

# Build packages
log "Building lcars-desktop package..."
nix build .#packages.x86_64-linux.lcars-desktop -o $BUILD_DIR/lcars-desktop

log "Building lcars-compositor package..."
nix build .#packages.x86_64-linux.lcars-compositor -o $BUILD_DIR/lcars-compositor

log "Building starfleet-cli package..."
nix build .#packages.x86_64-linux.starfleet-cli -o $BUILD_DIR/starfleet-cli

log "Building assimilation-tools package..."
nix build .#packages.x86_64-linux.assimilation-tools -o $BUILD_DIR/assimilation-tools

log "Building fleet-health-monitor package..."
nix build .#packages.x86_64-linux.fleet-health-monitor -o $BUILD_DIR/fleet-health-monitor

# Generate ISO for bridge
log "Generating ISO for bridge..."
nix build .#nixosConfigurations.bridge.config.system.build.isoImage -o $BUILD_DIR/bridge-iso

# Run tests
log "Running tests..."
nix flake check

log "Build and tests completed successfully!"
echo "===== Build Summary ====="
echo "Build directory: $BUILD_DIR"
echo "ISO image: $BUILD_DIR/bridge-iso/iso/starfleet-os.iso"
echo "===== End of Build Process ====="