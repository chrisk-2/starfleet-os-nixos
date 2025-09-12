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
    ../modules/borg/virtualization/vm-templates.nix
    
    # Storage modules
    ../modules/borg/storage/ceph-integration.nix
    ../modules/borg/storage/distributed-storage.nix
    
    # Orchestration modules
    ../modules/borg/orchestration/kubernetes-integration.nix
    ../modules/borg/orchestration/container-services.nix
    
    # Service discovery modules
    ../modules/borg/service-discovery/consul-integration.nix
    ../modules/borg/service-discovery/service-registry.nix
    
    # Sensor integration modules
    ../modules/borg/sensor-integration/home-assistant-integration.nix
    ../modules/borg/sensor-integration/mqtt-broker.nix
  ];

  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "borg-queen";
  networking.networkmanager.enable = true;

  # Enable Borg Collective Manager
  services.borg.collective-manager = {
    enable = true;
    role = "queen";
    droneId = "queen-node";
    adaptationLevel = "high";
    regenerationEnabled = true;
    collectiveAwareness = true;
    
    # Define drones in the collective
    drones = [
      { id = "drone-a"; address = "10.42.0.2"; role = "drone"; }
      { id = "drone-b"; address = "10.42.0.3"; role = "drone"; }
      { id = "edge-node"; address = "10.42.0.4"; role = "drone"; }
      { id = "edge-pi"; address = "10.42.0.5"; role = "edge"; }
    ];
    
    # API configuration
    apiEnabled = true;
    apiPort = 8080;
    apiAuth = true;
    apiToken = "borg-collective-token";
  };

  # Enable Borg Assimilation System
  services.borg.assimilation-system = {
    enable = true;
    role = "queen";
    targetNetworks = [
      "10.42.0.0/24"
      "192.168.1.0/24"
    ];
    assimilationSpeed = "adaptive";
    retentionPolicy = "preserve";
  };

  # Enable Borg Collective Database
  services.borg.collective-database = {
    enable = true;
    role = "primary";
    replicaNodes = [
      "10.42.0.2"
      "10.42.0.3"
    ];
    dataRetention = "30d";
    backupEnabled = true;
  };

  # Enable Borg Adaptation System
  services.borg.adaptation-system = {
    enable = true;
    role = "central";
    adaptationRules = [
      { name = "network-failure"; action = "reroute"; }
      { name = "storage-failure"; action = "redistribute"; }
      { name = "node-failure"; action = "reassign"; }
    ];
    selfHealingEnabled = true;
    learningEnabled = true;
  };

  # Enable Proxmox VE integration
  services.borg.virtualization.proxmox = {
    enable = true;
    role = "server";
    clusterName = "borg-collective";
    nodeAddress = "10.42.0.1";
  };

  # Enable VM templates
  services.borg.virtualization.templates = {
    enable = true;
    nixosTemplate = true;
    borgTemplate = true;
    nixosIsoUrl = "https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso";
  };

  # Enable Ceph integration
  services.borg.storage.ceph = {
    enable = true;
    role = "all";
    fsid = "00000000-0000-0000-0000-000000000001";
    monitorNodes = [ "10.42.0.1" "10.42.0.2" "10.42.0.3" ];
    monInitialMembers = [ "borg-queen" "borg-drone-a" "borg-drone-b" ];
    publicNetwork = "10.42.0.0/24";
    clusterNetwork = "10.42.1.0/24";
    osdDevices = [ "/dev/sdb" ];
  };

  # Enable distributed storage
  services.borg.storage.distributed = {
    enable = true;
    type = "ceph";
    mountPoints = {
      "/collective/data" = "cephfs:data";
      "/collective/vms" = "rbd:vms";
    };
    automount = true;
    createMountPoints = true;
  };

  # Enable Kubernetes integration
  services.borg.orchestration.kubernetes = {
    enable = true;
    role = "master";
    clusterToken = "borg-collective-token";
    k3sVersion = "latest";
    disableComponents = [ "traefik" "servicelb" ];
    clusterCidr = "10.42.0.0/16";
    serviceCidr = "10.43.0.0/16";
    extraFlags = [
      "--no-deploy=traefik"
      "--kube-controller-manager-arg=leader-elect=true"
    ];
  };

  # Enable container services
  services.borg.orchestration.services = {
    enable = true;
    namespace = "borg-collective";
    lcarsApi = true;
    collectiveManager = true;
    monitoring = true;
    neo4j = true;
    assimilationService = true;
    adaptationService = true;
  };

  # Enable Consul integration
  services.borg.discovery.consul = {
    enable = true;
    role = "server";
    datacenter = "borg-collective";
    nodeName = "borg-queen";
    enableUi = true;
    bootstrapExpect = 1;
    advertiseAddr = "10.42.0.1";
    encryptionKey = "borg-collective-encryption-key";
  };

  # Enable service registry
  services.borg.discovery.registry = {
    enable = true;
    autoRegisterServices = true;
    autoRegisterNodeExporter = true;
    autoRegisterConsulExporter = true;
    services = {
      "collective-api" = {
        name = "collective-api";
        tags = [ "api" "borg" ];
        address = "10.42.0.1";
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

  # Enable Home Assistant integration
  services.borg.sensors.homeAssistant = {
    enable = true;
    deployment = "remote";
    url = "http://10.42.0.5:8123";
    token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...";
    borgIntegration = true;
    mqttIntegration = true;
    mqttBroker = "10.42.0.1";
    mqttPort = 1883;
    mqttUsername = "homeassistant";
    mqttPassword = "homeassistant-password";
  };

  # Enable MQTT broker
  services.borg.sensors.mqtt = {
    enable = true;
    deployment = "local";
    port = 1883;
    websocketPort = 9001;
    enableWebsockets = true;
    allowAnonymous = false;
    persistentData = true;
    users = {
      "borg-queen" = {
        password = "borg-queen-password";
        acl = [ "readwrite #" ];
      };
      "borg-drone" = {
        password = "borg-drone-password";
        acl = [ "read #" "write sensors/#" ];
      };
      "edge-pi" = {
        password = "edge-pi-password";
        acl = [ "read #" "write sensors/edge-pi/#" ];
      };
      "homeassistant" = {
        password = "homeassistant-password";
        acl = [ "readwrite #" ];
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
    mtr
    
    # Storage tools
    lvm2
    parted
    gptfdisk
    
    # Monitoring tools
    prometheus
    grafana
    
    # Container tools
    docker
    podman
    kubectl
    kubernetes-helm
    
    # Development tools
    gcc
    gnumake
    python3
    python3Packages.pip
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