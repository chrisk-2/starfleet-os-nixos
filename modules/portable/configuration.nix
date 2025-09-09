{ config, lib, pkgs, ... }:

{
  imports = [
    ../common/base.nix
    ../common/security.nix
    ../common/networking.nix
  ];

  # Portable specific configuration
  system.stateVersion = "24.05";
  
  # Hostname
  networking.hostName = "mobile-assimilation-unit";
  
  # Laptop/Tablet specific configuration
  services.tlp.enable = true;  # Power management
  services.thermald.enable = true;  # Thermal management
  
  # LCARS-lite interface
  services.lcars-display.enable = true;
  services.lcars-display.mode = "borg";  # Default to Borg mode for portable units
  
  # Tunnel service for secure communication
  services.wireguard.interfaces = {
    wg0 = {
      ips = [ "10.42.0.5/24" ];
      listenPort = 51824;
      privateKeyFile = "/etc/wireguard/private.key";
      
      peers = [
        {
          # Bridge node
          publicKey = "bridge-public-key";
          allowedIPs = [ "10.42.0.0/24" ];
          endpoint = "uss-enterprise-bridge:51820";
          persistentKeepalive = 25;
        }
      ];
    };
  };
  
  # USB assimilation tools
  boot.kernelModules = [ "usb_storage" "hid" "usbhid" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ exfat-nofuse ];
  
  # System packages
  environment.systemPackages = with pkgs; [
    # Portable tools
    networkmanager
    networkmanagerapplet
    blueman
    
    # Security tools
    nmap
    wireshark
    tcpdump
    
    # USB tools
    usbutils
    pciutils
    
    # Utility tools
    htop
    iotop
    tmux
    screen
    rsync
  ];
  
  # User configuration
  users.users.portable = {
    isNormalUser = true;
    description = "Mobile Unit Operator";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
  };
  
  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      51824 # WireGuard
    ];
    allowedUDPPorts = [
      51824 # WireGuard
    ];
  };
  
  # Power management
  powerManagement.enable = true;
  powerManagement.powertop.enable = true;
  
  # Hardware acceleration
  hardware.opengl.enable = true;
  hardware.opengl.driSupport = true;
  hardware.pulseaudio.enable = true;
  
  # Bluetooth support
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
}