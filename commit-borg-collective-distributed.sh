#!/bin/bash

# Commit script for Borg Collective Distributed Systems Integration
# This script adds all the new files to the repository and commits them

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Borg Collective Distributed Systems Integration Commit Script ===${NC}"
echo -e "${YELLOW}Preparing to commit changes...${NC}"

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git is not installed. Please install git and try again.${NC}"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo -e "${RED}Not in a git repository. Please run this script from the root of the repository.${NC}"
    exit 1
fi

# Add new files to the repository
echo -e "${YELLOW}Adding new files to the repository...${NC}"

# Add module files
git add modules/borg/virtualization/proxmox-integration.nix
git add modules/borg/virtualization/vm-templates.nix
git add modules/borg/storage/ceph-integration.nix
git add modules/borg/storage/distributed-storage.nix
git add modules/borg/orchestration/kubernetes-integration.nix
git add modules/borg/orchestration/container-services.nix
git add modules/borg/service-discovery/consul-integration.nix
git add modules/borg/service-discovery/service-registry.nix
git add modules/borg/sensor-integration/home-assistant-integration.nix
git add modules/borg/sensor-integration/mqtt-broker.nix
git add modules/borg/collective-manager.nix

# Add configuration files
git add configurations/borg-queen-distributed.nix
git add configurations/borg-drone-distributed.nix
git add configurations/borg-edge-pi-distributed.nix

# Add build and deployment files
git add build-borg-collective-distributed.sh
git add BORG_COLLECTIVE_DISTRIBUTED_SYSTEMS_IMPLEMENTATION.md
git add BORG_COLLECTIVE_DISTRIBUTED_DEPLOYMENT_GUIDE.md
git add BORG_COLLECTIVE_DISTRIBUTED_SYSTEMS_SUMMARY.md

# Make the build script executable
chmod +x build-borg-collective-distributed.sh
git add build-borg-collective-distributed.sh

# Commit the changes
echo -e "${YELLOW}Committing changes...${NC}"
git commit -m "Add Borg Collective Distributed Systems Integration

This commit adds the following components:
- Virtualization integration with Proxmox VE
- Distributed storage with Ceph
- Container orchestration with Kubernetes (K3s)
- Service discovery with Consul
- Sensor integration with Home Assistant and MQTT
- Updated collective-manager.nix with distributed systems support
- Node configurations for Queen, Drone, and Edge-PI
- Build script for distributed systems integration
- Deployment guide and summary documentation"

echo -e "${GREEN}Changes committed successfully.${NC}"
echo -e "${YELLOW}You can now push the changes to the remote repository with:${NC}"
echo -e "  git push origin <branch-name>"

echo -e "${BLUE}=== Borg Collective Distributed Systems Integration ===${NC}"
echo -e "${GREEN}Resistance is futile. Your technological distinctiveness will be added to our own.${NC}"