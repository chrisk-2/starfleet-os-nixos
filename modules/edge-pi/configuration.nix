{ config, lib, pkgs, ... }:

{
  imports = [
    ../common/base.nix
    ../common/security.nix
    ../common/networking.nix
  ];

  # Edge-PI specific configuration
  system.stateVersion = "24.05";
  
  # Hostname
  networking.hostName = "edge-sensor-drone";
  
  # Raspberry Pi specific configuration
  boot.kernelPackages = pkgs.linuxPackages_rpi4;
  hardware.enableRedistributableFirmware = true;
  
  # Lightweight configuration for Raspberry Pi
  services.xserver.enable = false;  # Headless operation
  
  # MQTT relay
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        port = 1883;
        users = {
          edge-pi = {
            acl = [ "pattern readwrite #" ];
            password = "edge-pi-password";  # Should be replaced with proper secret management
          };
        };
      }
    ];
  };
  
  # ONVIF/RTSP discovery
  services.avahi.enable = true;
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  
  # Watchdog for resilience
  systemd.services.edge-watchdog = {
    description = "Edge PI Watchdog Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do ping -c 1 borg-drone-alpha || systemctl restart network-manager; sleep 60; done'";
      Restart = "always";
      RestartSec = 10;
    };
  };
  
  # Heartbeat service
  systemd.services.heartbeat = {
    description = "Edge PI Heartbeat Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "mosquitto.service" ];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.mosquitto}/bin/mosquitto_pub -h borg-drone-alpha -t 'edge/heartbeat' -u edge-pi -P edge-pi-password -m 'alive' -r";
      Restart = "always";
      RestartSec = 30;
    };
  };
  
  # System packages
  environment.systemPackages = with pkgs; [
    # Sensor tools
    mosquitto
    python3
    python3Packages.paho-mqtt
    python3Packages.requests
    
    # Camera tools
    ffmpeg
    v4l-utils
    
    # Utility tools
    htop
    iotop
    tmux
    screen
    rsync
  ];
  
  # User configuration
  users.users.edge = {
    isNormalUser = true;
    description = "Edge PI Operator";
    extraGroups = [ "wheel" "video" "gpio" ];
  };
  
  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      1883  # MQTT
      8554  # RTSP
    ];
    allowedUDPPorts = [
      5353  # mDNS
    ];
  };
}