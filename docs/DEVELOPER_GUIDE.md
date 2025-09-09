# Starfleet OS Developer Guide

This guide provides information for developers who want to contribute to or modify Starfleet OS.

## Table of Contents

1. [Development Environment Setup](#development-environment-setup)
2. [Repository Structure](#repository-structure)
3. [Building Components](#building-components)
4. [Testing](#testing)
5. [Adding New Features](#adding-new-features)
6. [Operational Modes](#operational-modes)
7. [Node Types](#node-types)
8. [Troubleshooting](#troubleshooting)

## Development Environment Setup

### Prerequisites

- NixOS or Linux with Nix installed
- Git
- Basic knowledge of Nix and NixOS
- Understanding of LCARS interface design principles

### Setting Up the Development Environment

1. Clone the repository:
   ```bash
   git clone https://github.com/chrisk-2/starfleet-os-nixos
   cd starfleet-os-nixos
   ```

2. Enter the development shell:
   ```bash
   nix develop
   ```

   This will provide you with all the necessary tools for development.

3. Build the system:
   ```bash
   ./build-test.sh
   ```

## Repository Structure

The repository is organized as follows:

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

### Key Files

- `flake.nix`: The main configuration file for the project
- `modules/lcars/display-server.nix`: LCARS display server configuration
- `modules/modes/mode-switcher.nix`: Operational mode switching system
- `modules/network/wireguard-mesh.nix`: WireGuard mesh network configuration
- `pkgs/lcars-desktop/default.nix`: LCARS desktop environment package

## Building Components

### Building the LCARS Desktop

```bash
nix build .#packages.x86_64-linux.lcars-desktop
```

### Building the Fleet Health Monitor

```bash
nix build .#packages.x86_64-linux.fleet-health-monitor
```

### Building a Complete Node Configuration

```bash
# Build Bridge node
nix build .#nixosConfigurations.bridge.config.system.build.toplevel

# Build Drone-A node
nix build .#nixosConfigurations.drone-a.config.system.build.toplevel

# Build Edge-PI node
nix build .#nixosConfigurations.edge-pi.config.system.build.toplevel
```

### Building ISO Images

```bash
# Build Bridge ISO
nix build .#nixosConfigurations.bridge.config.system.build.isoImage

# Or use the provided script
./nixos-generate-iso.sh bridge
```

## Testing

### Running Tests

```bash
# Run all tests
nix flake check

# Run specific tests
nix-build -A tests.lcars-desktop
```

### Testing the LCARS Interface

The LCARS interface can be tested in a virtual environment:

```bash
# Start a virtual machine with the LCARS interface
nixos-rebuild build-vm --flake .#bridge
./result/bin/run-*-vm
```

### Testing the WireGuard Mesh

To test the WireGuard mesh network:

1. Build multiple node configurations
2. Run them in separate VMs
3. Verify connectivity between nodes

## Adding New Features

### Adding a New Package

1. Create a new directory in `pkgs/`:
   ```bash
   mkdir -p pkgs/my-new-package
   ```

2. Create a `default.nix` file:
   ```nix
   { lib, stdenv, fetchFromGitHub, ... }:

   stdenv.mkDerivation rec {
     pname = "my-new-package";
     version = "1.0.0";

     src = ./.;

     # Add build instructions here

     meta = with lib; {
       description = "My new package for Starfleet OS";
       homepage = "https://starfleet-os.com";
       license = licenses.gpl3;
       maintainers = [ "Starfleet Engineering Corps" ];
       platforms = platforms.linux;
     };
   }
   ```

3. Add the package to `flake.nix`:
   ```nix
   packages.${system} = {
     # Existing packages...
     my-new-package = pkgs.callPackage ./pkgs/my-new-package { };
   };
   ```

### Adding a New Module

1. Create a new module file:
   ```bash
   mkdir -p modules/my-category
   touch modules/my-category/my-module.nix
   ```

2. Define the module:
   ```nix
   { config, lib, pkgs, ... }:

   with lib;

   let
     cfg = config.services.my-module;
   in
   {
     options.services.my-module = {
       enable = mkEnableOption "My new module";
       
       # Add more options here
     };

     config = mkIf cfg.enable {
       # Module implementation
     };
   }
   ```

3. Add the module to a node configuration:
   ```nix
   # In flake.nix
   nixosConfigurations = {
     bridge = nixpkgs.lib.nixosSystem {
       inherit system;
       modules = [
         # Existing modules...
         ./modules/my-category/my-module.nix
       ];
     };
   };
   ```

## Operational Modes

Starfleet OS supports multiple operational modes, each with its own theme and behavior:

### Mode Configuration

Modes are defined in `modules/modes/mode-switcher.nix`:

```nix
modes = {
  starfleet = {
    name = "Starfleet Mode";
    description = "Standard Federation operations";
    theme = "starfleet";
    services = { ... };
    colors = { ... };
  };
  
  # Other modes...
};
```

### Adding a New Mode

To add a new operational mode:

1. Add a new mode definition to `modules/modes/mode-switcher.nix`
2. Create theme colors in `flake.nix` under `lcarsColors`
3. Implement mode-specific services and configurations

## Node Types

Starfleet OS supports different node types, each with its own role in the fleet:

### Node Configuration

Nodes are defined in `flake.nix`:

```nix
nodeRoles = {
  bridge = {
    hostname = "uss-enterprise-bridge";
    description = "Command Console - Full LCARS visuals";
    services = [ ... ];
    interfaces = [ ... ];
  };
  
  # Other nodes...
};
```

### Adding a New Node Type

To add a new node type:

1. Add a new node definition to `flake.nix` under `nodeRoles`
2. Create a configuration directory in `modules/`
3. Define the node's configuration in `modules/my-node/configuration.nix`
4. Add the node to `nixosConfigurations` in `flake.nix`

## Troubleshooting

### Common Development Issues

#### Issue: Build Fails with Missing Dependencies

**Solution**: Check that all dependencies are properly declared in the package's `default.nix` file.

#### Issue: LCARS Interface Not Displaying Correctly

**Solution**: Verify that the LCARS display server is properly configured and that the theme colors are correctly defined.

#### Issue: WireGuard Mesh Network Not Connecting

**Solution**: Check the WireGuard configuration in `modules/network/wireguard-mesh.nix` and ensure that all nodes have the correct public keys.

#### Issue: Mode Switching Not Working

**Solution**: Verify that the mode-switcher service is enabled and that the mode definitions are correct.

### Getting Help

If you encounter issues that aren't covered here:

1. Check the existing GitHub issues
2. Join the #starfleet-os IRC channel on Libera.Chat
3. Contact the Starfleet OS Engineering Corps

## Contributing

We welcome contributions to Starfleet OS! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

Please ensure your code follows the project's style guidelines and includes appropriate documentation.

---

"Live long and prosper"