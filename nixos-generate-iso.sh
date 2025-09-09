#!/bin/bash
# Starfleet OS ISO Generator

set -e

# Configuration
BUILD_DIR="./build"
NIXOS_CONFIG_DIR="./nixos-configurations"
NODE_TYPES=("bridge" "drone-a" "drone-b" "edge-pi" "portable")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[STARFLEET OS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create build directory
mkdir -p "$BUILD_DIR"

# Generate ISO for each node type
generate_iso() {
    local node_type=$1
    local iso_name="starfleet-os-${node_type}"
    
    log "Generating ISO for ${node_type}..."
    
    # Build ISO
    nix build .#nixosConfigurations.${node_type}.config.system.build.isoImage \
        --out-link "$BUILD_DIR/${iso_name}"
    
    # Copy ISO
    cp result/iso/*.iso "$BUILD_DIR/${iso_name}.iso"
    
    log "ISO generated: $BUILD_DIR/${iso_name}.iso"
}

# Generate all ISOs
main() {
    log "Starting Starfleet OS ISO generation..."
    
    # Update flake
    nix flake update
    
    # Check if a specific node type was requested
    if [ $# -eq 1 ] && [[ " ${NODE_TYPES[@]} " =~ " $1 " ]]; then
        generate_iso "$1"
    else
        # Build each node type
        for node_type in "${NODE_TYPES[@]}"; do
            generate_iso "$node_type"
        done
    fi
    
    # Generate checksums
    cd "$BUILD_DIR"
    sha256sum *.iso > checksums.txt
    cd ..
    
    log "ISO generation complete!"
    log "Files available in: $BUILD_DIR"
    log "Checksums: $BUILD_DIR/checksums.txt"
    
    # Display summary
    echo ""
    echo "=== Starfleet OS ISO Summary ==="
    ls -lh "$BUILD_DIR"/*.iso
}

# Run main function with arguments
main "$@"