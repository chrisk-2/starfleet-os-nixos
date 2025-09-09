# Starfleet OS Troubleshooting Guide

This guide provides solutions for common issues you might encounter when using Starfleet OS.

## Table of Contents

1. [Installation Issues](#installation-issues)
2. [Boot Problems](#boot-problems)
3. [LCARS Interface Issues](#lcars-interface-issues)
4. [Network Problems](#network-problems)
5. [Mode Switching Issues](#mode-switching-issues)
6. [Node-Specific Problems](#node-specific-problems)
7. [Security Tools Issues](#security-tools-issues)
8. [Performance Optimization](#performance-optimization)
9. [Recovery Procedures](#recovery-procedures)
10. [Getting Help](#getting-help)

## Installation Issues

### ISO Won't Boot

**Symptoms**: The Starfleet OS ISO fails to boot, or you see errors during boot.

**Solutions**:
1. Verify the ISO image integrity:
   ```bash
   sha256sum starfleet-os-bridge.iso
   ```
   Compare with the checksum on the release page.

2. Try a different USB port or USB drive.

3. Check if your system supports UEFI boot and that it's enabled in BIOS.

4. Use a different tool to create the bootable USB:
   ```bash
   # On Linux
   dd if=starfleet-os-bridge.iso of=/dev/sdX bs=4M status=progress

   # On Windows
   # Use Rufus or Etcher
   ```

### Installation Freezes

**Symptoms**: The installation process freezes or hangs.

**Solutions**:
1. Try booting with nomodeset:
   - At the boot menu, press 'e' to edit the boot entry
   - Add `nomodeset` to the kernel parameters
   - Press F10 to boot

2. Check hardware compatibility:
   - Some hardware may require specific drivers
   - Try disabling hardware acceleration during installation

3. Verify system meets minimum requirements:
   - 4GB RAM
   - 20GB disk space
   - x86_64 processor

### Disk Partitioning Errors

**Symptoms**: Errors during disk partitioning or filesystem creation.

**Solutions**:
1. Check disk for errors:
   ```bash
   # From a live environment
   fsck -f /dev/sdX
   ```

2. Try manual partitioning:
   - Create partitions manually using `fdisk` or `parted`
   - Format partitions with appropriate filesystems
   - Mount and continue installation

3. If using encryption, ensure you have enough entropy:
   ```bash
   # Generate entropy
   dd if=/dev/urandom of=/dev/null
   ```

## Boot Problems

### System Won't Boot After Installation

**Symptoms**: After installation, the system fails to boot.

**Solutions**:
1. Boot from the installation media and chroot into the installed system:
   ```bash
   mount /dev/sdX1 /mnt
   mount /dev/sdX2 /mnt/boot  # If separate boot partition
   nixos-enter --root /mnt
   ```

2. Rebuild the system:
   ```bash
   nixos-rebuild switch
   ```

3. Check and fix bootloader:
   ```bash
   # For UEFI systems
   nixos-rebuild --install-bootloader switch
   ```

### Kernel Panic on Boot

**Symptoms**: You see a kernel panic message during boot.

**Solutions**:
1. Boot into a previous generation:
   - At the GRUB menu, select "NixOS - All configurations"
   - Choose a previous generation

2. Boot with fallback kernel parameters:
   - At the GRUB menu, press 'e' to edit the entry
   - Add `init=/bin/sh` to get a shell
   - Mount filesystem as read-write: `mount -o remount,rw /`

3. Rebuild the system with a stable kernel:
   ```bash
   nixos-rebuild switch --option boot.kernelPackages pkgs.linuxPackages_stable
   ```

### Missing GRUB Menu

**Symptoms**: GRUB menu doesn't appear, or system boots directly to default entry.

**Solutions**:
1. Hold Shift during boot to force GRUB menu to appear.

2. Edit GRUB configuration:
   ```bash
   # After booting or from a chroot
   nano /etc/default/grub
   # Set GRUB_TIMEOUT=5
   # Set GRUB_TIMEOUT_STYLE=menu
   nixos-rebuild switch
   ```

## LCARS Interface Issues

### LCARS Display Server Won't Start

**Symptoms**: After login, you see a black screen or error message instead of the LCARS interface.

**Solutions**:
1. Check the LCARS display server logs:
   ```bash
   journalctl -u lcars-display.service
   ```

2. Verify graphics drivers are installed and working:
   ```bash
   lspci -v | grep -A 10 VGA
   ```

3. Try starting the LCARS display server manually:
   ```bash
   systemctl start lcars-display.service
   ```

4. If using NVIDIA, ensure the proprietary drivers are installed:
   ```bash
   # In configuration.nix
   services.xserver.videoDrivers = [ "nvidia" ];
   hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;
   ```

### LCARS Interface Looks Incorrect

**Symptoms**: The LCARS interface appears distorted, has wrong colors, or elements are misaligned.

**Solutions**:
1. Check if the correct theme is applied:
   ```bash
   starfleet-mode-switch starfleet
   ```

2. Verify the display resolution:
   ```bash
   xrandr
   # Set appropriate resolution
   xrandr --output HDMI-1 --mode 1920x1080
   ```

3. Reset LCARS configuration:
   ```bash
   rm -rf ~/.config/lcars
   systemctl restart lcars-display.service
   ```

### LCARS Performance Issues

**Symptoms**: The LCARS interface is slow, laggy, or unresponsive.

**Solutions**:
1. Check system resources:
   ```bash
   top
   ```

2. Disable animations if needed:
   ```bash
   # Edit ~/.config/lcars/settings.conf
   animations = false
   ```

3. Ensure hardware acceleration is enabled:
   ```bash
   # In configuration.nix
   hardware.opengl.enable = true;
   hardware.opengl.driSupport = true;
   ```

4. If using a VM, ensure 3D acceleration is enabled in VM settings.

## Network Problems

### WireGuard Mesh Network Issues

**Symptoms**: Nodes can't communicate with each other over the WireGuard mesh.

**Solutions**:
1. Check WireGuard service status:
   ```bash
   systemctl status wireguard-wg0
   ```

2. Verify WireGuard configuration:
   ```bash
   cat /etc/wireguard/wg0.conf
   ```

3. Check firewall rules:
   ```bash
   # Ensure WireGuard port is open
   iptables -L
   ```

4. Test connectivity:
   ```bash
   ping 10.42.0.1  # Bridge node
   ```

5. Restart WireGuard:
   ```bash
   systemctl restart wireguard-wg0
   ```

### Network Discovery Not Working

**Symptoms**: Nodes don't automatically discover each other on the network.

**Solutions**:
1. Check mDNS/Avahi service:
   ```bash
   systemctl status avahi-daemon
   ```

2. Verify that multicast traffic is allowed on your network.

3. Try manual discovery:
   ```bash
   starfleet-discover --scan
   ```

4. Add nodes manually if needed:
   ```bash
   starfleet-add-node --name drone-a --address 10.42.0.2
   ```

### Internet Connection Issues

**Symptoms**: The system can't connect to the internet.

**Solutions**:
1. Check network configuration:
   ```bash
   ip addr
   ip route
   ```

2. Verify DNS resolution:
   ```bash
   ping 8.8.8.8  # Test IP connectivity
   ping google.com  # Test DNS resolution
   ```

3. Check NetworkManager status:
   ```bash
   systemctl status NetworkManager
   nmcli connection show
   ```

4. Try restarting networking:
   ```bash
   systemctl restart NetworkManager
   ```

## Mode Switching Issues

### Mode Won't Switch

**Symptoms**: The system doesn't change modes when requested.

**Solutions**:
1. Check mode switcher service:
   ```bash
   systemctl status lcars-mode-switcher
   ```

2. Try switching mode manually:
   ```bash
   LCARS_MODE=borg systemctl restart lcars-display
   ```

3. Verify user permissions:
   ```bash
   # Ensure user is in the starfleet group
   usermod -a -G starfleet $USER
   ```

4. Check mode configuration:
   ```bash
   cat /etc/lcars/modes.json
   ```

### Theme Not Applying Correctly

**Symptoms**: The interface doesn't change appearance when switching modes.

**Solutions**:
1. Restart the LCARS display server:
   ```bash
   systemctl restart lcars-display
   ```

2. Check theme files:
   ```bash
   ls -la /etc/lcars/themes/
   ```

3. Reset theme cache:
   ```bash
   rm -rf ~/.cache/lcars/themes
   ```

4. Verify mode environment variables:
   ```bash
   env | grep LCARS
   ```

## Node-Specific Problems

### Bridge Node Issues

**Symptoms**: The Bridge node doesn't display fleet health or camera feeds.

**Solutions**:
1. Check fleet health monitor service:
   ```bash
   systemctl status fleet-health-monitor
   ```

2. Verify camera operations service:
   ```bash
   systemctl status camera-operations
   ```

3. Check if other nodes are connected:
   ```bash
   starfleet-mesh-status
   ```

4. Restart bridge services:
   ```bash
   systemctl restart lcars-bridge-services
   ```

### Drone Node Issues

**Symptoms**: Drone nodes aren't reporting data or providing services.

**Solutions**:
1. Check drone services:
   ```bash
   # For Drone-A
   systemctl status monitoring-services logging-services backup-repo
   
   # For Drone-B
   systemctl status redundancy-services storage-extension sandbox-workloads
   ```

2. Verify network connectivity to Bridge:
   ```bash
   ping bridge.starfleet.local
   ```

3. Check service logs:
   ```bash
   journalctl -u monitoring-services
   ```

4. Restart drone services:
   ```bash
   systemctl restart drone-services
   ```

### Edge-PI Issues

**Symptoms**: Edge-PI nodes aren't detecting sensors or relaying data.

**Solutions**:
1. Check sensor discovery service:
   ```bash
   systemctl status onvif-discovery
   ```

2. Verify MQTT relay:
   ```bash
   systemctl status mqtt-relay
   ```

3. Check connected USB devices:
   ```bash
   lsusb
   ```

4. Restart sensor services:
   ```bash
   systemctl restart sensor-services
   ```

### Portable Node Issues

**Symptoms**: Portable nodes can't connect to the fleet or assimilate devices.

**Solutions**:
1. Check tunnel service:
   ```bash
   systemctl status tunnel-service
   ```

2. Verify assimilation tools:
   ```bash
   systemctl status assimilation-tools
   ```

3. Check USB permissions:
   ```bash
   ls -la /dev/sd*
   ```

4. Restart portable services:
   ```bash
   systemctl restart portable-services
   ```

## Security Tools Issues

### Pentest Suite Not Working

**Symptoms**: Security tools like Nmap, Hashcat, or Hydra aren't working properly.

**Solutions**:
1. Check if tools are installed:
   ```bash
   which nmap hashcat hydra
   ```

2. Verify user permissions:
   ```bash
   # Ensure user is in the security group
   usermod -a -G security $USER
   ```

3. Check tool configurations:
   ```bash
   cat /etc/starfleet/security/tools.conf
   ```

4. Try running tools with verbose output:
   ```bash
   nmap -v -A example.com
   ```

### BloodHound + Neo4j Issues

**Symptoms**: BloodHound or Neo4j database isn't working.

**Solutions**:
1. Check Neo4j service:
   ```bash
   systemctl status neo4j
   ```

2. Verify database connection:
   ```bash
   curl http://localhost:7474
   ```

3. Check BloodHound service:
   ```bash
   systemctl status bloodhound
   ```

4. Reset Neo4j password if needed:
   ```bash
   neo4j-admin set-initial-password newpassword
   ```

### GPU Acceleration for Security Tools

**Symptoms**: Hashcat or other tools aren't using GPU acceleration.

**Solutions**:
1. Check if GPU is detected:
   ```bash
   lspci | grep -i nvidia
   ```

2. Verify CUDA installation:
   ```bash
   nvidia-smi
   ```

3. Check Hashcat GPU support:
   ```bash
   hashcat -I
   ```

4. Enable GPU support in configuration:
   ```bash
   # In configuration.nix
   hardware.opengl.driSupport = true;
   hardware.opengl.extraPackages = with pkgs; [ libvdpau-va-gl vaapiVdpau ];
   ```

## Performance Optimization

### System Running Slowly

**Symptoms**: The system is sluggish or unresponsive.

**Solutions**:
1. Check system resources:
   ```bash
   top
   free -h
   df -h
   ```

2. Identify resource-intensive processes:
   ```bash
   ps aux --sort=-%cpu | head
   ```

3. Optimize services:
   ```bash
   # Disable unnecessary services
   systemctl disable service-name
   ```

4. Clean up disk space:
   ```bash
   nix-collect-garbage -d
   ```

### High Memory Usage

**Symptoms**: The system is using excessive memory.

**Solutions**:
1. Check memory usage:
   ```bash
   free -h
   ```

2. Identify memory-intensive processes:
   ```bash
   ps aux --sort=-%mem | head
   ```

3. Adjust service memory limits:
   ```bash
   # Edit /etc/systemd/system/service-name.service
   # Add: MemoryLimit=1G
   systemctl daemon-reload
   systemctl restart service-name
   ```

4. Add swap if needed:
   ```bash
   # In configuration.nix
   swapDevices = [ { device = "/swapfile"; size = 4096; } ];
   ```

### Battery Life on Portable Nodes

**Symptoms**: Poor battery life on laptop/portable nodes.

**Solutions**:
1. Enable power saving:
   ```bash
   # In configuration.nix
   services.tlp.enable = true;
   ```

2. Reduce screen brightness:
   ```bash
   brightnessctl set 50%
   ```

3. Disable unnecessary services:
   ```bash
   systemctl disable bluetooth
   ```

4. Use power-efficient mode:
   ```bash
   starfleet-mode-switch section31  # Section 31 mode uses less power
   ```

## Recovery Procedures

### Emergency Recovery

If your system won't boot or is severely broken:

1. Boot from the Starfleet OS ISO.

2. Mount your system:
   ```bash
   mount /dev/sdX1 /mnt
   mount /dev/sdX2 /mnt/boot  # If separate boot partition
   ```

3. Chroot into the system:
   ```bash
   nixos-enter --root /mnt
   ```

4. Roll back to a previous generation:
   ```bash
   # List generations
   nix-env --list-generations --profile /nix/var/nix/profiles/system
   
   # Switch to a previous generation
   nixos-rebuild switch --rollback
   ```

5. If needed, boot into recovery mode:
   ```bash
   # At GRUB menu, select recovery option
   # Or add 'single' to kernel parameters
   ```

### Data Recovery

If you need to recover data:

1. Boot from the Starfleet OS ISO.

2. Mount your system:
   ```bash
   mount /dev/sdX1 /mnt
   ```

3. Backup important data:
   ```bash
   cp -r /mnt/home/username/important /path/to/backup
   ```

4. If using encryption, unlock encrypted volumes:
   ```bash
   cryptsetup luksOpen /dev/sdX2 cryptroot
   mount /dev/mapper/cryptroot /mnt
   ```

5. Use BorgBackup for recovery if configured:
   ```bash
   borg extract /path/to/repo::archive-name
   ```

### Reset to Factory Settings

To reset Starfleet OS to factory settings:

1. Boot from the Starfleet OS ISO.

2. Reinstall the system:
   ```bash
   # Follow installation procedure
   ```

3. Alternatively, reset configuration while preserving data:
   ```bash
   # After booting or from chroot
   cp /etc/nixos/hardware-configuration.nix /tmp/
   rm -rf /etc/nixos/*
   cp /tmp/hardware-configuration.nix /etc/nixos/
   cp /etc/nixos/example-configuration.nix /etc/nixos/configuration.nix
   nixos-rebuild switch
   ```

## Getting Help

If you're still experiencing issues:

1. Check the documentation:
   - `/usr/share/doc/starfleet-os/`
   - Online documentation at https://starfleet-os.com/docs

2. Join the community:
   - IRC: #starfleet-os on Libera.Chat
   - Forum: https://forum.starfleet-os.com

3. Report bugs:
   - GitHub: https://github.com/chrisk-2/starfleet-os-nixos/issues
   - Include logs and system information

4. Generate a system report:
   ```bash
   starfleet-report > system-report.txt
   ```

5. Contact the Starfleet OS Engineering Corps:
   - Email: support@starfleet-os.com

---

"Live long and prosper"