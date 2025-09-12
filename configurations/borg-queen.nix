{ config, pkgs, ... }:

{
  imports = [
    ../modules/bridge/configuration.nix
    ../modules/lcars/display-server.nix
    ../modules/lcars/compositor.nix
    ../modules/security/pentest-suite.nix
    ../modules/fleet/health-monitoring.nix
    ../modules/fleet/camera-ops.nix
    ../modules/fleet/ai-helpers.nix
    ../modules/modes/mode-switcher.nix
    ../modules/borg/collective-manager.nix
    ../modules/borg/assimilation-system.nix
    ../modules/borg/adaptation-system.nix
    ../modules/borg/collective-database.nix
  ];

  # Set Borg mode as default
  services.lcars-mode-switcher = {
    enable = true;
    defaultMode = "borg";
    enableHotSwitch = true;
    requireAuthentication = true;
  };
  
  # Configure as Queen node
  services.borg-collective-manager = {
    enable = true;
    role = "queen";
    droneId = "queen-01";
    adaptationLevel = "high";
    regenerationEnabled = true;
    collectiveAwareness = true;
  };
  
  # Enable assimilation
  services.borg-assimilation = {
    enable = true;
    assimilationMethods = [ "usb" "network" "wireless" "manual" ];
    autoAssimilate = true;
    securityLevel = "high";
    assimilationTimeout = 600;
    quarantineEnabled = true;
    adaptationEnabled = true;
  };
  
  # Enable adaptation system
  services.borg-adaptation = {
    enable = true;
    adaptationLevel = "high";
    learningEnabled = true;
    threatResponseEnabled = true;
    resourceAdaptationEnabled = true;
    networkAdaptationEnabled = true;
    serviceAdaptationEnabled = true;
    adaptationInterval = 30;
  };
  
  # Configure collective database
  services.borg-collective-db = {
    enable = true;
    role = "primary";
    storageSize = "50G";
    replicationFactor = 3;
    retentionPeriod = "90d";
    backupInterval = "hourly";
    encryptionEnabled = true;
    autoHeal = true;
  };
  
  # WireGuard mesh configuration
  network.wireguard-mesh = {
    enable = true;
    nodeRole = "bridge";
    enableMeshDiscovery = true;
    enableFailover = true;
    encryptionLevel = "high";
  };
  
  # System packages
  environment.systemPackages = with pkgs; [
    # Borg Collective tools
    borg-collective-manager
    borg-assimilation-system
    
    # Network tools
    nmap
    wireshark
    tcpdump
    iperf3
    mtr
    
    # System monitoring
    htop
    iotop
    iftop
    glances
    
    # Security tools
    nmap
    hydra
    aircrack-ng
    john
    hashcat
    
    # Database tools
    postgresql
    cockroachdb
    
    # Development tools
    git
    vim
    tmux
    
    # Utilities
    curl
    wget
    jq
    ripgrep
    fd
  ];
  
  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    
    # Plymouth theme for Borg mode
    plymouth = {
      enable = true;
      theme = "borg";
      themePackages = [ pkgs.lcars-plymouth-theme ];
    };
    
    # Kernel parameters
    kernelParams = [
      "quiet"
      "splash"
      "vt.global_cursor_default=0"
      "usbcore.autosuspend=-1"
    ];
  };
  
  # Display configuration
  services.xserver = {
    enable = true;
    displayManager = {
      lightdm = {
        enable = true;
        background = "#000000";
        greeters.gtk = {
          enable = true;
          theme = {
            name = "borg";
            package = pkgs.lcars-login-manager;
          };
        };
      };
    };
  };
  
  # Sound configuration
  sound.enable = true;
  hardware.pulseaudio = {
    enable = true;
    package = pkgs.pulseaudioFull;
    extraConfig = ''
      # Enable Borg sound effects
      load-sample-lazy borg-assimilation ${pkgs.lcars-desktop}/share/sounds/borg-assimilation.wav
      load-sample-lazy borg-alert ${pkgs.lcars-desktop}/share/sounds/borg-alert.wav
      load-sample-lazy borg-regeneration ${pkgs.lcars-desktop}/share/sounds/borg-regeneration.wav
    '';
  };
  
  # Networking configuration
  networking = {
    hostName = "uss-enterprise-bridge";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22    # SSH
        80    # HTTP
        443   # HTTPS
        7777  # Collective communication
        7778  # Assimilation service
        7779  # Adaptation service
        9694  # Prometheus exporter
        26257 # CockroachDB
        8080  # CockroachDB HTTP
      ];
      allowedUDPPorts = [
        5353  # mDNS
        51820 # WireGuard
      ];
    };
  };
  
  # User configuration
  users.users.borg = {
    isNormalUser = true;
    description = "Borg Collective Operator";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    initialPassword = "resistance-is-futile";
  };
  
  # Automatic login for Borg mode
  services.xserver.displayManager.autoLogin = {
    enable = true;
    user = "borg";
  };
  
  # System services
  systemd.services.borg-voice = {
    description = "Borg Voice Announcements";
    wantedBy = [ "multi-user.target" ];
    after = [ "sound.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      User = "borg";
      ExecStart = "${pkgs.bash}/bin/bash -c 'paplay ${pkgs.lcars-desktop}/share/sounds/borg-startup.wav'";
    };
  };
  
  # Create required directories
  system.activationScripts.borgDirectories = ''
    mkdir -p /var/lib/borg/collective
    mkdir -p /var/lib/borg/assimilation
    mkdir -p /var/lib/borg/adaptation
    mkdir -p /var/lib/borg/models
    mkdir -p /var/lib/borg/data
    mkdir -p /var/lib/borg/quarantine
    chown -R borg:borg /var/lib/borg
  '';
  
  # System state version
  system.stateVersion = "24.05";
}