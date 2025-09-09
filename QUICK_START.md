# Starfleet OS - Quick Start Guide

## 🚀 Ready to Deploy - No Build Required

Your Starfleet OS is **pre-configured and ready**. Here's exactly what to do right now:

## Step 1: Choose Your First Node

### Option A: Bridge (Full LCARS Command Console)
- **Best for**: Complete Starfleet experience
- **Hardware**: Any x86_64 desktop/laptop with 8GB+ RAM
- **ISO**: Use `bridge` configuration

### Option B: Drone-A (Server Backbone)
- **Best for**: Hive operations and monitoring
- **Hardware**: Server or powerful desktop
- **ISO**: Use `drone-a` configuration

### Option C: Edge-PI (Raspberry Pi)
- **Best for**: Sensor network deployment
- **Hardware**: Raspberry Pi 3B+ with 16GB SD
- **ISO**: Use `edge-pi` configuration

## Step 2: Generate Your ISO (Choose ONE)

```bash
# For Bridge (Full LCARS experience)
./nixos-generate-iso.sh bridge

# For Drone-A (Server)
./nixos-generate-iso.sh drone-a

# For Edge-PI (Raspberry Pi)
./nixos-generate-iso.sh edge-pi
```

## Step 3: Installation Commands

### For Bridge/Drone-A (x86_64):
```bash
# Flash ISO to USB drive
sudo dd if=build/starfleet-os-bridge.iso of=/dev/sdX bs=4M status=progress

# Boot from USB and follow installation prompts
```

### For Edge-PI (Raspberry Pi):
```bash
# Flash ISO to SD card
sudo dd if=build/starfleet-os-edge-pi.iso of=/dev/sdX bs=4M status=progress

# Insert SD card into Raspberry Pi and power on
```

## Step 4: First Boot Commands

After installation, immediately run:

```bash
# Check system status
starfleet-status

# Switch to your preferred mode
starfleet-mode-switch starfleet    # Standard Federation
# OR
starfleet-mode-switch borg         # For Raspberry Pi

# Verify mesh network
starfleet-mesh-status

# Test security tools
starfleet-nmap --help
```

## 🎯 Hardware-Specific Commands

### Bridge Setup:
```bash
# Full LCARS with GPU acceleration
echo "LCARS_MODE=starfleet" >> /etc/environment
echo "GPU_ACCELERATION=true" >> /etc/environment
```

### Raspberry Pi Setup:
```bash
# Pi-optimized configuration
echo "LCARS_MODE=borg" >> /etc/environment
echo "SENSOR_MODE=true" >> /etc/environment
```

## 🔧 Immediate Testing

### Test 1: LCARS Interface
```bash
# Should show LCARS display
systemctl status lcars-display
```

### Test 2: Security Tools
```bash
# Test nmap integration
starfleet-nmap -sn 192.168.1.0/24
```

### Test 3: Mode Switching
```bash
# Switch modes dynamically
starfleet-mode-switch section31
```

## 📱 Mobile Deployment

### USB Stick Assimilation:
```bash
# Generate portable ISO
./nixos-generate-iso.sh portable

# Flash to USB for any computer
sudo dd if=build/starfleet-os-portable.iso of=/dev/sdX bs=4M status=progress
```

## 🚨 Common Issues & Solutions

### Issue 1: "Command not found"
**Solution**: You're running on non-NixOS. Install NixOS first.

### Issue 2: "Permission denied"
**Solution**: Use `sudo` for system-level commands.

### Issue 3: "Network unreachable"
**Solution**: Configure WireGuard mesh after basic setup.

## 📞 Get Started Right Now

### Immediate Actions:
1. **Choose your node type** from above
2. **Generate ISO** using nixos-generate-iso.sh
3. **Flash ISO** to USB drive or SD card
4. **Boot and install** on your hardware
5. **Join the mesh** after basic deployment

### Need Help?
- **Check README.md** for detailed instructions
- **Use validate-build.sh** to verify setup
- **Join the mesh** after basic deployment

## 🎯 Your Next 5 Minutes

1. **Pick your hardware** (desktop, server, or Raspberry Pi)
2. **Generate ISO** for your chosen node type
3. **Flash ISO** to USB drive or SD card
4. **Boot and install** Starfleet OS
5. **Join the hive** with WireGuard mesh

**You're ready to deploy Starfleet OS right now!**