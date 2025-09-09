{ config, lib, pkgs, ... }:

{
  imports = [
    ../common/base.nix
    ../common/security.nix
    ../common/networking.nix
  ];

  # Bridge-specific configuration
  system.stateVersion = "24.05";
  
  # Hostname
  networking.hostName = "uss-enterprise-bridge";
  
  # Full LCARS interface
  services.lcars-display.enable = true;
  services.lcars-display.mode = "starfleet";
  
  # Graphics drivers for full LCARS
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };
  
  # High-performance GPU support
  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.powerManagement.enable = true;
  
  # Full desktop environment
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = false; # Pure LCARS
  
  # Bridge-specific services
  services.fleet-health.enable = true;
  services.camera-ops.enable = true;
  services.ai-helpers.enable = true;
  services.alarm-system.enable = true;
  
  # System packages: Security tools, development tools, and utilities
  environment.systemPackages = with pkgs; [
    # Security tools
    nmap
    masscan
    hydra
    hashcat
    john
    bloodhound
    wireshark
    bettercap
    
    # Development tools
    git
    vim
    emacs
    vscode
    docker
    kubectl
    terraform
    ansible
  ];
  
  # User configuration
  users.users.starfleet = {
    isNormalUser = true;
    description = "Starfleet Captain";
    extraGroups = [ "wheel" "video" "audio" "networkmanager" ];
    packages = with pkgs; [
      firefox
      chromium
      thunderbird
      libreoffice
      gimp
      vlc
    ];
  };
}