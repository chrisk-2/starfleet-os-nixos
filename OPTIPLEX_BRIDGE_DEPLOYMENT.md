# 🖥️ OptiPlex Bridge Deployment Guide
# Starfleet OS Command Console

## Immediate Deployment Options

### Option 1: Already Running NixOS
If your OptiPlex is already running NixOS:

```bash
# Copy the bridge configuration
sudo cp /tmp/starfleet-bridge-config.nix /etc/nixos/configuration.nix

# Deploy Starfleet OS immediately
sudo nixos-rebuild switch

# Reboot into Starfleet OS
sudo reboot
```

### Option 2: Fresh NixOS Installation
If installing NixOS fresh:

1. **Download NixOS** from nixos.org
2. **Boot from USB** on your OptiPlex
3. **During installation**, use this configuration:

```nix
# In your /etc/nixos/configuration.nix
{ config, pkgs, ... }:
{
  imports = [
    # Include the bridge configuration
    ./starfleet-bridge-config.nix
  ];

  # Essential bridge settings
  networking.hostName = "uss-enterprise-bridge";
  services.lcars-display.enable = true;
  services.lcars-display.mode = "starfleet";
}
```

### Option 3: Configuration Testing
```bash
# Test the configuration first
nix-instantiate --eval /tmp/starfleet-bridge-config.nix
```

## OptiPlex-Specific Optimizations

### Hardware Detection
```bash
# Check your OptiPlex hardware
lspci | grep -i vga    # Graphics card
lscpu                  # CPU info
lsblk                  # Storage info
```

### Graphics Configuration
For OptiPlex with NVIDIA:
```bash
# Enable NVIDIA drivers
hardware.nvidia.modesetting.enable = true;
hardware.nvidia.powerManagement.enable = true;
```

For OptiPlex with Intel:
```bash
# Intel graphics
services.xserver.videoDrivers = [ "intel" ];
```

## First Boot Commands

After deployment, immediately test:

```bash
# Check Starfleet OS status
starfleet-status

# Test LCARS interface
systemctl status lcars-display

# Switch operational modes
starfleet-mode-switch starfleet    # Standard Federation
starfleet-mode-switch section31    # Covert operations
starfleet-mode-switch borg         # Assimilation mode

# Test security tools
starfleet-nmap --help
starfleet-hashcat --help

# Network mesh status
starfleet-mesh-status
```

## Bridge-Specific Features

### 1. Command Console Interface
- Full LCARS display with 1920x1080 resolution
- GPU-accelerated rendering
- Real-time fleet health monitoring
- Camera operations center

### 2. Security Hub
- Integrated pentest suite
- Hashcat with GPU acceleration
- Network reconnaissance tools
- Active directory analysis

### 3. Mesh Network Hub
- WireGuard mesh coordinator
- Service discovery master
- Health monitoring center
- Failover management

### 4. Operational Modes
```bash
# Available modes for bridge
starfleet-mode-switch starfleet    # Standard Federation
starfleet-mode-switch section31    # Covert operations
starfleet-mode-switch borg         # Assimilation protocols
starfleet-mode-switch terran       # Terran Empire mode
starfleet-mode-switch holodeck     # Simulation environment
```

## Quick Deployment Script

Run this on your OptiPlex:

```bash
# Make deployment script executable
chmod +x DEPLOY_BRIDGE.sh

# Deploy bridge configuration
./DEPLOY_BRIDGE.sh

# Verify deployment
./bridge-quick-setup.sh
```

## Immediate Next Steps After Deployment

1. **Configure network** for mesh connectivity
2. **Test operational modes** with the switcher
3. **Join other nodes** to the mesh network
4. **Test security tools** with your network
5. **Deploy camera operations** if you have cameras

## Ready to Deploy Right Now

Your OptiPlex bridge configuration is complete and ready. Choose your deployment method:

- **NixOS installed**: Use the configuration files
- **Fresh install**: Use during NixOS installation
- **Testing**: Use nix-instantiate for validation

The OptiPlex is ready to serve as your Starfleet command console!