{ config, pkgs, ... }:

{
  imports = [
    # Base modules
    ../modules/borg/collective-manager.nix
    ../modules/borg/assimilation-system.nix
    ../modules/borg/collective-database.nix
    ../modules/borg/adaptation-system.nix
    
    # Virtualization modules
    ../modules/borg/virtualization/proxmox-integration.nix
    
    # Storage modules
    ../modules/borg/storage/ceph-integration.nix
    ../modules/borg/storage/distributed-storage.nix
    
    # Orchestration modules
    ../modules/borg/orchestration/kubernetes-integration.nix
    
    # Service discovery modules
    ../modules/borg/service-discovery/consul-integration.nix
    ../modules/borg/service-discovery/service-registry.nix
    
    # Sensor integration modules
    ../modules/borg/sensor-integration/mqtt-broker.nix
  ];

  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "borg-drone-a";  # Change for each drone
  networking.networkmanager.enable = true;

  # Enable Borg Collective Manager
  services.borg.collective-manager = {
    enable = true;
    role = "drone";
    droneId = "drone-a";  # Change for each drone
    queenAddress = "10.42.0.1";
    adaptationLevel = "medium";
    regenerationEnabled = true;
    collectiveAwareness = true;
    
    # API configuration
    apiEnabled = true;
    apiPort = 8080;
    apiAuth = true;
    apiToken = "borg-collective-token";
  };

  # Enable Borg Assimilation System
  services.borg.assimilation-system = {
    enable = true;
    role = "drone";
    queenAddress = "10.42.0.1";
    assimilationSpeed = "normal";
    retentionPolicy = "preserve";
  };

  # Enable Borg Collective Database
  services.borg.collective-database = {
    enable = true;
    role = "replica";
    primaryNode = "10.42.0.1";
    dataRetention = "15d";
    backupEnabled = true;
  };

  # Enable Borg Adaptation System
  services.borg.adaptation-system = {
    enable = true;
    role = "node";
    centralNode = "10.42.0.1";
    selfHealingEnabled = true;
    learningEnabled = true;
  };

  # Enable Proxmox VE integration
  services.borg.virtualization.proxmox = {
    enable = true;
    role = "client";
    clusterName = "borg-collective";
    nodeAddress = "10.42.0.2";  # Change for each drone
    serverNodes = [ "10.42.0.1" ];
  };

  # Enable Ceph integration
  services.borg.storage.ceph = {
    enable = true;
    role = "osd";
    fsid = "00000000-0000-0000-0000-000000000001";
    monitorNodes = [ "10.42.0.1" "10.42.0.2" "10.42.0.3" ];
    publicNetwork = "10.42.0.0/24";
    clusterNetwork = "10.42.1.0/24";
    osdDevices = [ "/dev/sdb" ];  # Change for each drone
  };

  # Enable distributed storage
  services.borg.storage.distributed = {
    enable = true;
    type = "ceph";
    mountPoints = {
      "/collective/data" = "cephfs:data";
    };
    automount = true;
    createMountPoints = true;
  };

  # Enable Kubernetes integration
  services.borg.orchestration.kubernetes = {
    enable = true;
    role = "worker";
    masterAddress = "10.42.0.1";
    clusterToken = "borg-collective-token";
  };

  # Enable Consul integration
  services.borg.discovery.consul = {
    enable = true;
    role = "client";
    datacenter = "borg-collective";
    nodeName = "borg-drone-a";  # Change for each drone
    serverNodes = [ "10.42.0.1" ];
    encryptionKey = "borg-collective-encryption-key";
  };

  # Enable service registry
  services.borg.discovery.registry = {
    enable = true;
    autoRegisterServices = true;
    autoRegisterNodeExporter = true;
    services = {
      "drone-service" = {
        name = "drone-service";
        tags = [ "drone" "borg" ];
        address = "10.42.0.2";  # Change for each drone
        port = 8080;
        checks = [
          {
            type = "http";
            target = "http://localhost:8080/health";
            interval = "30s";
          }
        ];
      };
    };
  };

  # Enable MQTT client
  services.borg.sensors.mqtt = {
    enable = true;
    deployment = "local";
    port = 1883;
    allowAnonymous = false;
    users = {
      "borg-drone" = {
        password = "borg-drone-password";
        acl = [ "read #" "write sensors/drone-a/#" ];  # Change for each drone
      };
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    # System utilities
    vim
    wget
    git
    htop
    tmux
    curl
    jq
    
    # Networking tools
    nmap
    tcpdump
    iperf
    
    # Storage tools
    lvm2
    parted
    
    # Container tools
    docker
    podman
    kubectl
    
    # Development tools
    python3
  ];

  # Enable SSH
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  services.openssh.settings.PasswordAuthentication = false;

  # User configuration
  users.users.borg = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" "libvirtd" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... borg@collective"
    ];
  };

  # System settings
  system.stateVersion = "24.05";
}