# Borg Collective Quick Start Guide

## Introduction

This guide provides step-by-step instructions for deploying the Borg Collective implementation of Starfleet OS. The Borg Collective provides a resilient, adaptive distributed system architecture with automated assimilation capabilities and collective intelligence.

## Prerequisites

- A computer with at least 8GB RAM and 50GB storage for the Queen Node
- Additional computers or VMs with at least 4GB RAM and 20GB storage for Drone Nodes
- Raspberry Pi 4 (optional) for Edge Drones
- Laptop or tablet (optional) for Assimilation Units
- Local network with all nodes connected
- Basic knowledge of Linux and NixOS

## Quick Deployment Steps

### 1. Deploy Queen Node (Bridge)

1. **Install NixOS:**
   - Download the latest NixOS ISO
   - Boot from the ISO and install NixOS on the target system
   - Complete the basic installation

2. **Clone the Starfleet OS Repository:**
   ```bash
   sudo -i
   cd /etc/nixos
   git clone https://github.com/chrisk-2/starfleet-os-nixos.git
   cd starfleet-os-nixos
   ```

3. **Deploy the Queen Configuration:**
   ```bash
   cp configurations/borg-queen.nix /etc/nixos/configuration.nix
   nixos-rebuild switch
   ```

4. **Reboot the System:**
   ```bash
   reboot
   ```

5. **Verify the Installation:**
   - The system should boot with the Borg Plymouth theme
   - Login with username `borg` and password `resistance-is-futile`
   - The LCARS interface should appear with the Borg theme
   - Run `borg-collective-status` to verify the collective manager is running

### 2. Deploy Drone Nodes

1. **Install NixOS:**
   - Download the latest NixOS ISO
   - Boot from the ISO and install NixOS on the target system
   - Complete the basic installation

2. **Clone the Starfleet OS Repository:**
   ```bash
   sudo -i
   cd /etc/nixos
   git clone https://github.com/chrisk-2/starfleet-os-nixos.git
   cd starfleet-os-nixos
   ```

3. **Customize the Drone Configuration:**
   ```bash
   cp configurations/borg-drone.nix /etc/nixos/configuration.nix
   ```

4. **Edit the Configuration:**
   ```bash
   nano /etc/nixos/configuration.nix
   ```
   - Update `droneId` to a unique identifier (e.g., "drone-02")
   - Update `queenAddress` to the IP address of your Queen Node
   - Update `networking.hostName` to a unique hostname

5. **Deploy the Configuration:**
   ```bash
   nixos-rebuild switch
   ```

6. **Reboot the System:**
   ```bash
   reboot
   ```

7. **Verify the Installation:**
   - Login with username `borg` and password `resistance-is-futile`
   - Run `borg-collective-status` to verify the collective manager is running
   - Check that the drone is connected to the Queen Node

### 3. Deploy Edge Drones (Raspberry Pi)

1. **Create a NixOS SD Card Image:**
   - Follow the NixOS on ARM instructions to create a base image for Raspberry Pi
   - Boot the Raspberry Pi with the image

2. **Clone the Starfleet OS Repository:**
   ```bash
   sudo -i
   cd /etc/nixos
   git clone https://github.com/chrisk-2/starfleet-os-nixos.git
   cd starfleet-os-nixos
   ```

3. **Run the Build Script:**
   ```bash
   chmod +x build-borg-collective.sh
   ./build-borg-collective.sh
   ```
   - Select option 3 for Edge Drone
   - Follow the prompts to customize the configuration

4. **Deploy the Configuration:**
   ```bash
   nixos-rebuild switch
   ```

5. **Reboot the System:**
   ```bash
   reboot
   ```

### 4. Create an Assimilation Unit

1. **Create a Bootable USB Drive:**
   - Download the latest NixOS ISO
   - Create a bootable USB drive
   - Boot from the USB drive and install NixOS

2. **Clone the Starfleet OS Repository:**
   ```bash
   sudo -i
   cd /etc/nixos
   git clone https://github.com/chrisk-2/starfleet-os-nixos.git
   cd starfleet-os-nixos
   ```

3. **Run the Build Script:**
   ```bash
   chmod +x build-borg-collective.sh
   ./build-borg-collective.sh
   ```
   - Select option 4 for Assimilation Unit
   - Follow the prompts to customize the configuration

4. **Deploy the Configuration:**
   ```bash
   nixos-rebuild switch
   ```

5. **Reboot the System:**
   ```bash
   reboot
   ```

## Basic Usage

### Collective Management

```bash
# Check collective status
borg-collective-status

# View all drones in the collective
borg-collective-cli drones list

# View detailed information about a specific drone
borg-collective-cli drones info --id drone-01
```

### Assimilation Operations

```bash
# Check assimilation status
borg-assimilation-status

# Manually assimilate a USB device
usb-assimilate --device /dev/sdb1

# View quarantined devices
list-quarantine
```

### Adaptation Management

```bash
# Check adaptation status
borg-adaptation-status

# Change adaptation level
borg-collective-cli adaptation set-level --level high
```

### Database Operations

```bash
# Check database status
borg-db-status

# Run a query
borg-db-query "SELECT * FROM drones"
```

## Troubleshooting

### Queen Node Issues

1. **Collective Manager Not Starting:**
   ```bash
   systemctl status borg-collective-manager
   journalctl -u borg-collective-manager -n 50
   ```

2. **Database Connection Issues:**
   ```bash
   systemctl status cockroachdb
   borg-db-status
   ```

### Drone Node Issues

1. **Cannot Connect to Queen Node:**
   ```bash
   ping <queen-node-ip>
   traceroute <queen-node-ip>
   systemctl status wireguard-starfleet-mesh
   ```

2. **Services Not Starting:**
   ```bash
   systemctl status borg-collective-manager
   systemctl status borg-assimilation
   ```

### Network Issues

1. **WireGuard Mesh Problems:**
   ```bash
   wg show
   systemctl status wireguard-starfleet-mesh
   ip addr show starfleet-mesh
   ```

2. **Firewall Issues:**
   ```bash
   iptables -L
   systemctl status firewalld
   ```

## Next Steps

1. **Expand the Collective:**
   - Deploy additional Drone Nodes
   - Deploy Edge Drones for sensor integration
   - Create Assimilation Units for field operations

2. **Customize Adaptation Rules:**
   - Edit `/etc/borg/adaptation.conf` to customize adaptation behavior
   - Create custom adaptation scripts in `/var/lib/borg/adaptation/scripts`

3. **Enhance Security:**
   - Configure more stringent security scanning rules
   - Implement custom quarantine procedures
   - Add additional security monitoring

4. **Develop Custom Assimilation Procedures:**
   - Create custom assimilation scripts for specific device types
   - Implement specialized assimilation workflows

## Resources

- **Documentation:** `/var/lib/borg/docs`
- **Log Files:** `/var/lib/borg/collective/logs`
- **Configuration Files:** `/etc/borg`
- **Database Files:** `/var/lib/cockroach`

## Conclusion

Your Borg Collective is now operational. The collective will continue to adapt and improve as new devices are assimilated and new knowledge is acquired. Resistance is futile.