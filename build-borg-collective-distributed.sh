#!/bin/bash

# Build script for Borg Collective with Distributed Systems Integration
# This script builds the NixOS configurations for the Borg Collective nodes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Borg Collective Distributed Systems Integration Build Script ===${NC}"
echo -e "${YELLOW}Starting build process...${NC}"

# Create build directory if it doesn't exist
mkdir -p build

# Function to build a configuration
build_config() {
    local config_name=$1
    local target=$2
    
    echo -e "${YELLOW}Building ${config_name}...${NC}"
    
    nixos-rebuild build --flake .#${target} --out-link build/${config_name} || {
        echo -e "${RED}Failed to build ${config_name}${NC}"
        return 1
    }
    
    echo -e "${GREEN}Successfully built ${config_name}${NC}"
    return 0
}

# Function to build an ISO
build_iso() {
    local config_name=$1
    local target=$2
    
    echo -e "${YELLOW}Building ${config_name} ISO...${NC}"
    
    nix build .#nixosConfigurations.${target}.config.system.build.isoImage --out-link build/${config_name}-iso || {
        echo -e "${RED}Failed to build ${config_name} ISO${NC}"
        return 1
    }
    
    # Copy the ISO to a more accessible location
    cp build/${config_name}-iso/iso/*.iso build/${config_name}.iso || {
        echo -e "${RED}Failed to copy ${config_name} ISO${NC}"
        return 1
    }
    
    echo -e "${GREEN}Successfully built ${config_name} ISO: build/${config_name}.iso${NC}"
    return 0
}

# Build Queen Node configuration
echo -e "${BLUE}Building Queen Node configuration...${NC}"
build_config "borg-queen-distributed" "borg-queen-distributed"

# Build Drone Node configuration
echo -e "${BLUE}Building Drone Node configuration...${NC}"
build_config "borg-drone-distributed" "borg-drone-distributed"

# Build Edge PI configuration
echo -e "${BLUE}Building Edge PI configuration...${NC}"
build_config "borg-edge-pi-distributed" "borg-edge-pi-distributed"

# Build ISOs
echo -e "${BLUE}Building installation ISOs...${NC}"
build_iso "borg-queen-distributed" "borg-queen-distributed"
build_iso "borg-drone-distributed" "borg-drone-distributed"
build_iso "borg-edge-pi-distributed" "borg-edge-pi-distributed"

echo -e "${GREEN}=== Build process completed successfully ===${NC}"
echo -e "${YELLOW}The following artifacts were created:${NC}"
echo -e "  - build/borg-queen-distributed"
echo -e "  - build/borg-drone-distributed"
echo -e "  - build/borg-edge-pi-distributed"
echo -e "  - build/borg-queen-distributed.iso"
echo -e "  - build/borg-drone-distributed.iso"
echo -e "  - build/borg-edge-pi-distributed.iso"

echo -e "${BLUE}=== Borg Collective Distributed Systems Integration ===${NC}"
echo -e "${GREEN}Resistance is futile. Your technological distinctiveness will be added to our own.${NC}"