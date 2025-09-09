{ config, lib, pkgs, ... }:

{
  imports = [
    ../common/base.nix
    ../common/security.nix
    ../common/networking.nix
  ];

  # Drone-B specific configuration
  system.stateVersion = "24.05";
  
  # Hostname
  networking.hostName = "borg-drone-beta";
  
  # Server-focused configuration
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  
  # Redundancy services
  services.keepalived = {
    enable = true;
    vrrpInstances = {
      VI_1 = {
        interface = "eth0";
        state = "BACKUP";
        virtualRouterId = 51;
        priority = 100;
        virtualIps = [
          {
            addr = "192.168.1.200/24";
          }
        ];
      };
    };
  };
  
  # Storage extension
  services.nfs.server = {
    enable = true;
    exports = ''
      /var/lib/storage 192.168.1.0/24(rw,sync,no_subtree_check)
    '';
  };
  
  # Sandbox workloads
  virtualisation.docker.enable = true;
  virtualisation.podman.enable = true;
  virtualisation.libvirtd.enable = true;
  
  # System packages
  environment.systemPackages = with pkgs; [
    # Server tools
    htop
    iotop
    iftop
    ncdu
    tmux
    screen
    rsync
    
    # Storage tools
    nfs-utils
    lvm2
    mdadm
    
    # Virtualization tools
    docker-compose
    podman-compose
    virt-manager
    
    # Redundancy tools
    keepalived
    haproxy
  ];
  
  # User configuration
  users.users.drone = {
    isNormalUser = true;
    description = "Drone Beta Operator";
    extraGroups = [ "wheel" "networkmanager" "docker" "libvirtd" ];
  };
  
  # Storage configuration
  fileSystems."/var/lib/storage" = {
    device = "/dev/disk/by-label/STORAGE";
    fsType = "ext4";
    options = [ "defaults" "noatime" ];
  };
  
  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      80    # HTTP
      443   # HTTPS
      2049  # NFS
      111   # NFS
      2376  # Docker
      8080  # HAProxy stats
    ];
    allowedUDPPorts = [
      2049  # NFS
      111   # NFS
    ];
  };
}