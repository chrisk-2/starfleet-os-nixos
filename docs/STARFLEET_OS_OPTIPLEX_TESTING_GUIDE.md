# Starfleet OS OptiPlex Testing Guide
# Command Console Deployment & Testing

## Hardware Requirements

### Recommended Dell OptiPlex Specifications
- **CPU**: Intel Core i5/i7 (6th gen or newer)
- **RAM**: 16GB minimum, 32GB recommended
- **Storage**: 256GB SSD minimum, 512GB recommended
- **Graphics**: NVIDIA GTX 1050 or better (for LCARS acceleration)
- **Network**: Gigabit Ethernet + WiFi (for mesh networking)
- **USB**: 3.0 ports for assimilation tools
- **Display**: 1080p minimum, dual displays recommended

### BIOS Configuration
1. Enter BIOS (F2 during boot)
2. Enable Virtualization Technology (VT-x)
3. Enable UEFI boot mode
4. Disable Secure Boot
5. Set boot order to USB first
6. Enable all CPU cores
7. Enable hardware acceleration
8. Save and exit

## Preparation

### 1. Create Installation Media
```bash
# Clone the repository if not already done
git clone https://github.com/chrisk-2/starfleet-os-nixos.git
cd starfleet-os-nixos

# Build the ISO
./build-test.sh
./nixos-generate-iso.sh bridge

# Write ISO to USB drive (replace sdX with your USB device)
sudo dd if=build/bridge-iso/iso/starfleet-os.iso of=/dev/sdX bs=4M status=progress
```

### 2. Prepare OptiPlex Hardware
1. Ensure OptiPlex is powered off
2. Connect primary display to GPU
3. Connect secondary display if available
4. Connect Ethernet cable
5. Connect keyboard and mouse
6. Insert USB installation media
7. Power on and boot from USB (F12 for boot menu)

## Installation Methods

### Method 1: Full Installation (Recommended)

1. **Boot from USB**
   - Insert Starfleet OS USB drive
   - Power on OptiPlex
   - Press F12 for boot menu
   - Select USB drive

2. **Partition Disk**
   ```bash
   # Launch terminal
   # Create partitions
   sudo parted /dev/sda -- mklabel gpt
   sudo parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
   sudo parted /dev/sda -- set 1 boot on
   sudo parted /dev/sda -- mkpart primary 512MiB 100%
   
   # Format partitions
   sudo mkfs.fat -F 32 -n boot /dev/sda1
   sudo mkfs.ext4 -L nixos /dev/sda2
   
   # Mount partitions
   sudo mount /dev/sda2 /mnt
   sudo mkdir -p /mnt/boot
   sudo mount /dev/sda1 /mnt/boot
   ```

3. **Generate NixOS Configuration**
   ```bash
   # Generate base configuration
   sudo nixos-generate-config --root /mnt
   
   # Copy Starfleet OS bridge configuration
   sudo cp /etc/nixos/bridge-configuration.nix /mnt/etc/nixos/configuration.nix
   ```

4. **Install NixOS with Starfleet OS**
   ```bash
   # Install NixOS
   sudo nixos-install
   
   # Set root password when prompted
   
   # Reboot into Starfleet OS
   sudo reboot
   ```

### Method 2: Direct Deployment (For Existing NixOS)

1. **Copy Bridge Configuration**
   ```bash
   # Copy the bridge configuration
   sudo cp /tmp/starfleet-bridge-config.nix /etc/nixos/configuration.nix
   
   # Deploy Starfleet OS immediately
   sudo nixos-rebuild switch
   
   # Reboot into Starfleet OS
   sudo reboot
   ```

### Method 3: Testing Without Installation

1. **Boot into Live Environment**
   - Boot from Starfleet OS USB
   - Select "Try Starfleet OS without installing"
   - Log in with username "starfleet" and password "starfleet"

2. **Test LCARS Interface**
   ```bash
   # Start LCARS display
   starfleet-lcars-start
   
   # Test mode switching
   starfleet-mode-switch starfleet
   ```

## Post-Installation Testing

### 1. Initial Boot Verification
- Verify LCARS boot splash appears
- Check boot animation plays correctly
- Verify boot sound plays
- Monitor boot progress indicators
- Confirm successful boot to login screen

### 2. LCARS Login System Testing
- Verify LCARS-themed login screen appears
- Test login with default credentials (username: starfleet, password: starfleet)
- Test different session types (lcars, lcars-lite, fallback)
- Verify successful login to LCARS desktop
- Test user switching if multiple users configured

### 3. LCARS Desktop Environment Testing
```bash
# Check LCARS display service
systemctl status lcars-display

# Verify compositor is running
systemctl status lcars-compositor

# Check display resolution
xrandr

# Test GPU acceleration
glxinfo | grep "direct rendering"
```

### 4. Mode Switching Testing
```bash
# Test each operational mode
starfleet-mode-switch starfleet
starfleet-mode-switch section31
starfleet-mode-switch borg
starfleet-mode-switch terran
starfleet-mode-switch holodeck

# Verify theme changes with each mode
# Check that applications adapt to the current mode
```

### 5. Bridge-Specific Services Testing
```bash
# Check fleet health monitoring
systemctl status fleet-health-monitor
curl http://localhost:8080/status

# Test camera operations
systemctl status camera-ops
camera-ops-status

# Check AI helpers
systemctl status ai-helpers
ai-helper-query "system status"

# Test alarm system
systemctl status alarm-system
alarm-system-test --silent
```

### 6. Network Configuration Testing
```bash
# Check network interfaces
ip addr

# Test internet connectivity
ping -c 4 google.com

# Check WireGuard mesh status
systemctl status wireguard-mesh
starfleet-mesh-status

# Test mesh connectivity (if other nodes available)
starfleet-mesh-ping all
```

### 7. Security Tools Testing
```bash
# Test pentest suite
starfleet-nmap -sV localhost
starfleet-hashcat --benchmark

# Test network reconnaissance
starfleet-recon --local-network

# Check BloodHound + Neo4j (if installed)
systemctl status bloodhound-neo4j
```

### 8. Holodeck Mode Testing
```bash
# Switch to Holodeck mode
starfleet-mode-switch holodeck

# Start Holodeck UI
holodeck-ui

# Create test simulation
holodeck-create-simulation test starship-bridge

# Start simulation
holodeck-start-simulation test

# Test simulation functionality
holodeck-simulation-status test

# Stop simulation
holodeck-stop-simulation test
```

## Performance Testing

### 1. System Resource Monitoring
```bash
# Monitor CPU usage
top

# Monitor memory usage
free -h

# Monitor disk usage
df -h

# Monitor GPU usage
nvidia-smi -l 1
```

### 2. LCARS Interface Performance
```bash
# Test LCARS rendering performance
lcars-benchmark

# Check frame rate
lcars-display-info

# Test with different resolutions
lcars-display-config --resolution=1080p
lcars-display-config --resolution=4k
```

### 3. Network Performance
```bash
# Test network throughput
iperf3 -s  # On one node
iperf3 -c [server-ip]  # On another node

# Test WireGuard mesh performance
starfleet-mesh-benchmark
```

### 4. Boot Time Measurement
```bash
# Measure boot time
systemd-analyze

# Measure boot time by phase
systemd-analyze blame

# Create boot time chart
systemd-analyze plot > boot-chart.svg
```

## Hardware Compatibility Testing

### 1. Graphics Card Testing
```bash
# Check GPU detection
lspci | grep -i vga

# Test GPU acceleration
glxinfo | grep "direct rendering"

# Test LCARS with GPU acceleration
lcars-display-test --gpu-acceleration
```

### 2. Multi-Monitor Testing
```bash
# Check detected displays
xrandr

# Configure dual monitors
lcars-display-config --dual-monitor

# Test LCARS spanning across monitors
lcars-display-test --span-monitors
```

### 3. Audio Testing
```bash
# Check audio devices
aplay -l

# Test LCARS sound effects
lcars-sound-test

# Test boot sound
lcars-boot-sound-test
```

### 4. USB Device Testing
```bash
# Check USB devices
lsusb

# Test USB assimilation tools
starfleet-usb-scan

# Test USB storage devices
starfleet-usb-mount /dev/sdX1
```

## Troubleshooting Common Issues

### 1. LCARS Display Issues
```bash
# Restart LCARS display
sudo systemctl restart lcars-display

# Check logs
journalctl -u lcars-display -f

# Test with fallback mode
starfleet-mode-switch --fallback
```

### 2. Boot Issues
```bash
# Boot with verbose mode
# Add 'verbose' to kernel parameters in GRUB

# Check boot logs
journalctl -b

# Test with failsafe configuration
starfleet-boot --failsafe
```

### 3. Network Issues
```bash
# Reset network configuration
sudo systemctl restart NetworkManager

# Regenerate WireGuard keys
starfleet-mesh-keygen

# Test connectivity
starfleet-mesh-diagnostics
```

### 4. Graphics Driver Issues
```bash
# Check loaded drivers
lsmod | grep -i nvidia
lsmod | grep -i intel

# Reinstall graphics drivers
sudo nixos-rebuild switch --upgrade

# Test with basic graphics mode
starfleet-display --basic-mode
```

## Reporting Test Results

After completing testing, please document your results:

1. **Create Test Report**
   ```bash
   # Generate test report
   starfleet-test-report --generate
   ```

2. **Collect System Information**
   ```bash
   # Collect system information
   starfleet-system-info > system-info.txt
   
   # Collect logs
   journalctl -b > boot-log.txt
   ```

3. **Take Screenshots**
   ```bash
   # Take screenshot of LCARS interface
   lcars-screenshot > lcars-screenshot.png
   ```

4. **Submit Report**
   - Email test report to starfleet-os-dev@example.com
   - Include system information and logs
   - Attach screenshots of the LCARS interface
   - Document any issues encountered and steps to reproduce

## Next Steps After Successful Testing

### 1. Join Bridge to Fleet
```bash
# Configure bridge as fleet coordinator
starfleet-fleet-config --role=bridge

# Start fleet services
starfleet-fleet-start

# Check fleet status
starfleet-fleet-status
```

### 2. Add Additional Nodes
```bash
# Generate node configuration
starfleet-node-config --type=drone-a > drone-a-config.nix
starfleet-node-config --type=drone-b > drone-b-config.nix

# Deploy node configurations to other systems
# Follow similar installation steps on those systems
```

### 3. Configure Mesh Networking
```bash
# Generate mesh keys
starfleet-mesh-keygen

# Configure mesh network
starfleet-mesh-config --role=bridge

# Add nodes to mesh
starfleet-mesh-add-node drone-a 192.168.1.101
starfleet-mesh-add-node drone-b 192.168.1.102
```

### 4. Deploy Edge Sensors
```bash
# Generate edge-pi configuration
starfleet-node-config --type=edge-pi > edge-pi-config.nix

# Flash Raspberry Pi image
starfleet-flash-pi --config=edge-pi-config.nix --device=/dev/sdX

# Add edge-pi to fleet
starfleet-fleet-add-node edge-pi
```

### 5. Complete Fleet Deployment
```bash
# Verify all nodes are connected
starfleet-fleet-status

# Test fleet communication
starfleet-fleet-ping-all

# Configure fleet services
starfleet-fleet-services --enable-all

# Monitor fleet health
starfleet-fleet-health
```

## Conclusion

Your OptiPlex bridge is now ready to serve as the command console for your Starfleet OS deployment! The bridge node acts as the central control point for your fleet, providing a complete LCARS interface for managing all aspects of your Starfleet operations.

If you encounter any issues during testing or deployment, please refer to the troubleshooting section or contact the Starfleet OS development team for assistance.

Thank you for testing Starfleet OS and helping to improve the project!