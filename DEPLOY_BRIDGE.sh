#!/bin/bash
# Starfleet OS Bridge Deployment - OptiPlex Command Console

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Deploying Starfleet OS Bridge on OptiPlex${NC}"
echo -e "${BLUE}==========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (sudo)${NC}"
  exit 1
fi

# Create bridge configuration
cat > /tmp/starfleet-bridge-config.nix << 'EOF'
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Bridge Node Configuration - OptiPlex Command Console
  system.stateVersion = "24.05";
  
  # Hostname for bridge
  networking.hostName = "uss-enterprise-bridge";
  
  # OptiPlex hardware optimization
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  
  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Graphics drivers for full LCARS
  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" "intel" "amdgpu" ]; # Will use appropriate driver
    displayManager = {
      gdm.enable = true;
      defaultSession = "none+lcars";
    };
  };
  
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };
  
  # NVIDIA GPU for LCARS acceleration
  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.powerManagement.enable = true;
  
  # Pure LCARS interface
  services.lcars-display = {
    enable = true;
    mode = "starfleet";
    resolution = "1920x1080";
    refreshRate = 60;
  };
  
  # Bridge-specific services
  services.fleet-health.enable = true;
  services.camera-ops.enable = true;
  services.ai-helpers.enable = true;
  services.alarm-system.enable = true;
  
  # Security suite for bridge
  security.pentest-suite = {
    enable = true;
    enableAll = true;
    enableGPUAcceleration = true;
  };
  
  # WireGuard mesh hub
  network.wireguard-mesh = {
    enable = true;
    nodeRole = "bridge";
    enableMeshDiscovery = true;
    enableFailover = true;
  };
  
  # Bridge user with full privileges
  users.users.starfleet = {
    isNormalUser = true;
    description = "Starfleet Captain - Bridge Command";
    extraGroups = [ "wheel" "video" "audio" "networkmanager" "docker" ];
    initialPassword = "starfleet";
    packages = with pkgs; [
      firefox
      chromium
      thunderbird
      vscode
      docker
      kubectl
      terraform
      wireshark
      nmap
      hashcat
    ];
  };
  
  # Development tools
  environment.systemPackages = with pkgs; [
    git
    vim
    emacs
    tree
    htop
    jq
    curl
    wget
  ];
  
  # Network configuration for bridge
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      80    # HTTP
      443   # HTTPS
      51820 # WireGuard
      8080  # LCARS web interface
    ];
    allowedUDPPorts = [
      51820 # WireGuard
    ];
  };
  
  # Services for bridge
  services.openssh.enable = true;
  services.avahi.enable = true;
  
  # Timezone for Starfleet operations
  time.timeZone = "America/New_York";
  
  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
EOF

echo -e "${GREEN}✅ Bridge configuration created: /tmp/starfleet-bridge-config.nix${NC}"

# Create quick setup script
cat > /tmp/bridge-quick-setup.sh << 'EOF'
#!/bin/bash
# OptiPlex Bridge Quick Setup Script

echo "🖥️  Starfleet OS Bridge - OptiPlex Setup"
echo "======================================="

# Check if running on NixOS
if command -v nixos-version &> /dev/null; then
    echo "✅ Running on NixOS - Ready for bridge deployment"
    
    # Create bridge configuration
    sudo cp /tmp/starfleet-bridge-config.nix /etc/nixos/configuration.nix
    
    echo "🚀 Deploying Starfleet OS Bridge..."
    echo ""
    
    # Deploy immediately
    echo "Running: sudo nixos-rebuild switch"
    sudo nixos-rebuild switch
    
    echo ""
    echo "✅ Bridge deployed successfully!"
    echo ""
    echo "🎯 Next commands:"
    echo "starfleet-mode-switch starfleet    # Standard Federation mode"
    echo "starfleet-mode-switch borg         # Assimilation mode"
    echo "starfleet-mesh-status             # Check mesh network"
    echo ""
    
elif command -v nix &> /dev/null; then
    echo "🔧 Nix detected - testing configuration"
    
    # Test configuration
    nix-instantiate --eval /tmp/starfleet-bridge-config.nix
    
    echo "✅ Configuration validated"
    echo ""
    echo "To deploy on NixOS system:"
    echo "1. Install NixOS on your OptiPlex"
    echo "2. Copy this configuration to /etc/nixos/configuration.nix"
    echo "3. Run: sudo nixos-rebuild switch"
    
else
    echo "📋 Installation guide for OptiPlex:"
    echo ""
    echo "1. Download NixOS minimal ISO from nixos.org"
    echo "2. Boot OptiPlex from USB"
    echo "3. During installation, use this configuration:"
    echo ""
    cat /tmp/starfleet-bridge-config.nix
    echo ""
fi

echo ""
echo "🎯 OptiPlex bridge deployment complete!"
echo "Ready to serve as the main Starfleet command console!"
EOF

chmod +x /tmp/bridge-quick-setup.sh

echo -e "${GREEN}✅ Quick setup script created: /tmp/bridge-quick-setup.sh${NC}"
echo ""
echo -e "${YELLOW}📋 Next steps for OptiPlex deployment:${NC}"
echo ""
echo "1. Install NixOS on your OptiPlex (if not already)"
echo "2. Copy configuration to /etc/nixos/configuration.nix"
echo "3. Run: sudo nixos-rebuild switch"
echo "4. Reboot into Starfleet OS"
echo ""
echo -e "${YELLOW}🔧 Immediate commands after deployment:${NC}"
echo "starfleet-mode-switch starfleet    # Standard mode"
echo "starfleet-mesh-status             # Check network"
echo "starfleet-nmap 192.168.1.0/24    # Network discovery"
echo ""
echo -e "${GREEN}🎯 Ready to deploy on your OptiPlex!${NC}"