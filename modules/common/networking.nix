{ config, lib, pkgs, ... }:

{
  # Common networking configuration for all node types
  
  # Enable NetworkManager
  networking.networkmanager.enable = true;
  
  # Enable wireless support
  networking.wireless.enable = false; # Managed by NetworkManager
  
  # Configure firewall
  networking.firewall = {
    enable = true;
    allowPing = true;
    
    # Default allowed ports
    allowedTCPPorts = [
      22    # SSH
      80    # HTTP
      443   # HTTPS
    ];
    
    allowedUDPPorts = [
      53    # DNS
    ];
  };
  
  # Enable mDNS
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
      workstation = true;
    };
  };
  
  # Network tools
  environment.systemPackages = with pkgs; [
    dig
    whois
    traceroute
    nmap
    iperf
    tcpdump
    wireshark
    netcat
    socat
  ];
  
  # Enable IPv4 forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };
  
  # Configure hosts file
  networking.extraHosts = ''
    # Starfleet OS Mesh Network
    10.42.0.1 uss-enterprise-bridge bridge.starfleet.local
    10.42.0.2 borg-drone-alpha drone-a.starfleet.local
    10.42.0.3 borg-drone-beta drone-b.starfleet.local
    10.42.0.4 edge-sensor-drone edge-pi.starfleet.local
    10.42.0.5 mobile-assimilation-unit portable.starfleet.local
  '';
}