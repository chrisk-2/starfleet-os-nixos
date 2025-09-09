{ config, lib, pkgs, ... }:

{
  imports = [
    ../common/base.nix
    ../common/security.nix
    ../common/networking.nix
  ];

  # Drone-A specific configuration
  system.stateVersion = "24.05";
  
  # Hostname
  networking.hostName = "borg-drone-alpha";
  
  # Server-focused configuration
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  
  # Monitoring and logging
  services.prometheus.enable = true;
  services.grafana.enable = true;
  services.loki.enable = true;
  
  # Backup repository
  services.borgbackup.jobs = {
    hive-backup = {
      paths = [
        "/var/lib/hive-data"
        "/etc/starfleet"
      ];
      exclude = [
        "*.tmp"
      ];
      repo = "/var/lib/backups/hive";
      encryption = {
        mode = "repokey";
        passCommand = "cat /etc/starfleet/backup-passphrase";
      };
      compression = "auto,lzma";
      startAt = "hourly";
    };
  };
  
  # Neo4j for BloodHound
  services.neo4j = {
    enable = true;
    package = pkgs.neo4j;
  };
  
  # WireGuard mesh networking
  networking.nat.enable = true;
  networking.nat.externalInterface = "eth0";
  networking.nat.internalInterfaces = [ "wg0" ];
  
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
    
    # Monitoring tools
    prometheus
    grafana
    loki
    
    # Database tools
    neo4j
    postgresql
    
    # Backup tools
    borgbackup
    restic
  ];
  
  # User configuration
  users.users.drone = {
    isNormalUser = true;
    description = "Drone Alpha Operator";
    extraGroups = [ "wheel" "networkmanager" ];
  };
  
  # Storage configuration
  fileSystems."/var/lib/hive-data" = {
    device = "/dev/disk/by-label/HIVE_DATA";
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
      3000  # Grafana
      7474  # Neo4j HTTP
      7687  # Neo4j Bolt
      9090  # Prometheus
    ];
  };
}