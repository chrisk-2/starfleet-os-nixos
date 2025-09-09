# Starfleet OS - Pure LCARS NixOS Distribution

## Overview

Starfleet OS is a fully integrated LCARS operating system built on NixOS, designed to be Starfleet from top to bottom. This is not an overlay or theme - it's a complete operating system with pure LCARS interface, distributed hive architecture, and multiple operational modes.

## Features

### Pure LCARS Interface
- **Native LCARS Display Server**: Custom display server built specifically for LCARS
- **LCARS Compositor**: Wayland compositor with LCARS theming
- **LCARS Widgets**: Complete widget library for LCARS interface elements
- **Multi-Mode Support**: Dynamic theming for Starfleet/Section 31/Borg/Terran/Holodeck modes

### Distributed Hive Architecture
- **Bridge (Command Console)**: Full LCARS interface, fleet health monitoring, camera operations
- **Drone-A (Hive Backbone)**: Core monitoring, logging, backup repository, BloodHound + Neo4j
- **Drone-B (Auxiliary Node)**: Service redundancy, storage extension, sandbox workloads
- **Edge-PI (Sensor Drone)**: Raspberry Pi 3B, ONVIF/RTSP discovery, MQTT relay
- **Portable (Expansion Node)**: Mobile hive presence, USB assimilation, LCARS-lite interface

### Security & Pentest Suite
- **Network Tools**: Nmap, Masscan, Wireshark, Bettercap
- **Password Tools**: Hashcat (GPU accelerated), Hydra, John the Ripper
- **Reconnaissance**: BloodHound + Neo4j, Active Directory analysis
- **Hardware Hacking**: USB spoofing, RF scanning, device assimilation

### Operational Modes
- **Starfleet Mode**: Standard Federation operations
- **Section 31 Mode**: Covert operations with dark LCARS skin
- **Borg Mode**: Assimilation protocols with green/black interface
- **Terran Empire Mode**: Maximum aggression with gold/black interface
- **Holodeck Mode**: Simulation environment with grid-lined interface

## Installation

### Prerequisites
- NixOS installed on target system
- Internet connection for package downloads
- Sufficient disk space (minimum 20GB)

### Quick Start
```bash
# Clone the repository
git clone https://github.com/chrisk-2/starfleet-os-nixos
cd starfleet-os-nixos

# Generate ISO for your node type
./nixos-generate-iso.sh bridge      # Bridge configuration
./nixos-generate-iso.sh drone-a     # Drone-A configuration
./nixos-generate-iso.sh drone-b     # Drone-B configuration
./nixos-generate-iso.sh edge-pi     # Raspberry Pi configuration
./nixos-generate-iso.sh portable    # Portable configuration

# Flash ISO to USB drive
sudo dd if=build/starfleet-os-bridge.iso of=/dev/sdX bs=4M status=progress
```

### Node-Specific Installation

#### Bridge (Full LCARS)
- **Hardware**: Dell OptiPlex or equivalent
- **Graphics**: Dedicated GPU recommended for full LCARS experience
- **Network**: Gigabit Ethernet for mesh networking
- **Installation**: Use bridge ISO with full desktop environment

#### Drone-A/B (Servers)
- **Hardware**: Dell Inspiron Server or equivalent
- **Storage**: RAID configuration for redundancy
- **Network**: Multiple NICs for mesh networking
- **Installation**: Use drone ISO with server configuration

#### Edge-PI (Raspberry Pi)
- **Hardware**: Raspberry Pi 3B or newer
- **Storage**: 16GB+ SD card
- **Network**: WiFi and Ethernet support
- **Installation**: Use edge-pi ISO with ARM configuration

#### Portable (Laptop/Tablet)
- **Hardware**: Any x86_64 laptop or tablet
- **Storage**: 8GB+ USB drive
- **Network**: WiFi support for mobile operation
- **Installation**: Use portable ISO

## Configuration

### Node Roles
Each node has a specific role in the Starfleet OS hive:

- **Bridge**: Command and control center
- **Drone-A**: Primary hive backbone
- **Drone-B**: Auxiliary/backup services
- **Edge-PI**: Sensor network node
- **Portable**: Mobile assimilation unit

### Mode Switching
Switch between operational modes using:
```bash
# Command line
starfleet-mode-switch starfleet
starfleet-mode-switch section31
starfleet-mode-switch borg
starfleet-mode-switch terran
starfleet-mode-switch holodeck

# GUI interface
lcars-mode-gui
```

### Network Configuration
All nodes automatically join the WireGuard mesh network:
- **Network**: 10.42.0.0/24
- **Encryption**: High-grade encryption
- **Discovery**: Automatic node discovery
- **Failover**: Automatic failover support

## Usage

### Basic Commands
```bash
# Check system status
starfleet-status

# Monitor fleet health
fleet-health-monitor

# View network mesh
starfleet-mesh-status

# Switch operational mode
starfleet-mode-switch [mode]

# Access security tools
starfleet-nmap [targets]
starfleet-hashcat [options]
starfleet-recon [targets]
```

### LCARS Interface
The LCARS interface provides:
- **Fleet Health Dashboards**: Real-time monitoring
- **Camera Operations**: ONVIF/RTSP discovery and management
- **Security Tools**: Integrated pentest suite
- **Mode Switching**: Dynamic interface changes
- **Alarm System**: Visual and audible alerts

### Security Features
- **Encryption**: All communications encrypted
- **Authentication**: Multi-factor authentication
- **Authorization**: Role-based access control
- **Audit Logging**: Comprehensive security logging
- **Intrusion Detection**: Real-time threat monitoring

## Development

### Building from Source
```bash
# Development environment
nix develop

# Build specific component
nix build .#packages.x86_64-linux.lcars-desktop

# Test configuration
nixos-rebuild build --flake .#bridge

# Run build test script
./build-test.sh
```

### Contributing
1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

### Architecture
- **NixOS Base**: Immutable, declarative configuration
- **LCARS Display Server**: Custom display server
- **Wayland Compositor**: Modern graphics stack
- **WireGuard Mesh**: Secure networking
- **Security Tools**: Integrated pentest suite
- **Mode System**: Dynamic operational modes

### Repository Structure
```
starfleet-os-nixos/
├── flake.nix              # Main flake configuration
├── modules/               # NixOS modules
│   ├── bridge/            # Bridge node configuration
│   ├── common/            # Common modules
│   ├── drone-a/           # Drone-A node configuration
│   ├── drone-b/           # Drone-B node configuration
│   ├── edge-pi/           # Edge-PI node configuration
│   ├── fleet/             # Fleet management
│   ├── hive/              # Hive architecture
│   ├── lcars/             # LCARS interface
│   ├── modes/             # Operational modes
│   ├── network/           # Network configuration
│   ├── portable/          # Portable node configuration
│   ├── security/          # Security tools
│   ├── sensors/           # Sensor integration
│   └── system/            # System utilities
├── pkgs/                  # Custom packages
│   ├── assimilation-tools/# Hardware assimilation tools
│   ├── fleet-health-monitor/ # Fleet monitoring dashboard
│   ├── lcars-compositor/  # LCARS compositor
│   ├── lcars-desktop/     # LCARS desktop environment
│   └── starfleet-cli/     # Command-line utilities
├── home/                  # Home-manager configurations
├── build/                 # Build outputs
├── docs/                  # Documentation
└── assets/                # Images and resources
```

## Troubleshooting

### Common Issues
- **Display Problems**: Check graphics drivers
- **Network Issues**: Verify WireGuard configuration
- **Mode Switching**: Ensure authentication
- **Security Tools**: Check tool dependencies

### Support
- **Documentation**: Check docs/ directory
- **Issues**: GitHub issues
- **Community**: Starfleet OS community
- **IRC**: #starfleet-os on Libera.Chat

## Recent Updates
- **2025-09-09**: Added Fleet Health Monitor dashboard with LCARS UI
- **2025-09-09**: Implemented LCARS desktop environment with Wayland compositor
- **2025-09-09**: Added assimilation tools for hardware integration
- **2025-09-09**: Improved build system with test script
- **2025-09-09**: Enhanced documentation and repository structure

## License
GPL-3.0 License - See LICENSE file for details

## Starfleet OS Engineering Corps
"Live long and prosper"