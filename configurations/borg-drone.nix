{ config, pkgs, ... }:

{
  imports = [
    ../modules/drone-a/configuration.nix
    ../modules/hive/monitoring-services.nix
    ../modules/hive/logging-services.nix
    ../modules/hive/backup-repo.nix
    ../modules/security/bloodhound-neo4j.nix
    ../modules/network/wireguard-mesh.nix
    ../modules/borg/collective-manager.nix
    ../modules/borg/assimilation-system.nix
    ../modules/borg/adaptation-system.nix
    ../modules/borg/collective-database.nix
  ];

  # Configure as Drone node
  services.borg-collective-manager = {
    enable = true;
    role = "drone";
    droneId = "drone-01";
    queenAddress = "10.42.0.1";
    adaptationLevel = "medium";
    regenerationEnabled = true;
    collectiveAwareness = true;
  };
  
  # Enable assimilation with limited capabilities
  services.borg-assimilation = {
    enable = true;
    assimilationMethods = [ "network" "manual" ];
    autoAssimilate = false;  # Require queen approval
    securityLevel = "high";
    assimilationTimeout = 300;
    quarantineEnabled = true;
    adaptationEnabled = true;
  };
  
  # Enable adaptation system
  services.borg-adaptation = {
    enable = true;
    adaptationLevel = "medium";
    learningEnabled = true;
    threatResponseEnabled = true;
    resourceAdaptationEnabled = true;
    networkAdaptationEnabled = true;
    serviceAdaptationEnabled = false;  # Limited service adaptation
    adaptationInterval = 60;
  };
  
  # Configure collective database
  services.borg-collective-db = {
    enable = true;
    role = "replica";
    storageSize = "20G";
    replicationFactor = 3;
    retentionPeriod = "30d";
    backupInterval = "daily";
    encryptionEnabled = true;
    autoHeal = true;
  };
  
  # WireGuard mesh configuration
  network.wireguard-mesh = {
    enable = true;
    nodeRole = "drone-a";
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
    tcpdump
    iperf3
    mtr
    
    # System monitoring
    htop
    iotop
    iftop
    glances
    
    # Database tools
    postgresql
    cockroachdb
    
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
  
  # Networking configuration
  networking = {
    hostName = "borg-drone-alpha";
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
        9090  # Prometheus
        3000  # Grafana
      ];
      allowedUDPPorts = [
        5353  # mDNS
        51821 # WireGuard
      ];
    };
  };
  
  # Monitoring services
  services.prometheus = {
    enable = true;
    port = 9090;
    
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
        port = 9100;
      };
    };
    
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];
          labels = {
            instance = "borg-drone-alpha";
          };
        }];
      }
      {
        job_name = "borg-collective";
        static_configs = [{
          targets = [ "localhost:9694" ];
          labels = {
            instance = "borg-drone-alpha";
          };
        }];
      }
    ];
  };
  
  # Grafana configuration
  services.grafana = {
    enable = true;
    port = 3000;
    addr = "0.0.0.0";
    
    provision = {
      enable = true;
      datasources = {
        settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://localhost:9090";
              isDefault = true;
            }
          ];
        };
      };
    };
  };
  
  # Loki for log aggregation
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;
      
      server = {
        http_listen_port = 3100;
      };
      
      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore = {
              store = "inmemory";
            };
            replication_factor = 1;
          };
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 1048576;
        chunk_retain_period = "30s";
      };
      
      schema_config = {
        configs = [{
          from = "2020-05-15";
          store = "boltdb-shipper";
          object_store = "filesystem";
          schema = "v11";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }];
      };
      
      storage_config = {
        boltdb_shipper = {
          active_index_directory = "/var/lib/loki/boltdb-shipper-active";
          cache_location = "/var/lib/loki/boltdb-shipper-cache";
          cache_ttl = "24h";
          shared_store = "filesystem";
        };
        
        filesystem = {
          directory = "/var/lib/loki/chunks";
        };
      };
      
      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };
    };
  };
  
  # Promtail for log collection
  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = 3101;
        grpc_listen_port = 0;
      };
      
      positions = {
        filename = "/var/lib/promtail/positions.yaml";
      };
      
      clients = [{
        url = "http://localhost:3100/loki/api/v1/push";
      }];
      
      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "borg-drone-alpha";
            };
          };
          relabel_configs = [
            {
              source_labels = ["__journal__systemd_unit"];
              target_label = "unit";
            }
          ];
        }
        {
          job_name = "borg-collective";
          static_configs = [
            {
              targets = ["localhost"];
              labels = {
                job = "borg-collective";
                host = "borg-drone-alpha";
                __path__ = "/var/lib/borg/collective/*.log";
              };
            }
          ];
        }
        {
          job_name = "borg-assimilation";
          static_configs = [
            {
              targets = ["localhost"];
              labels = {
                job = "borg-assimilation";
                host = "borg-drone-alpha";
                __path__ = "/var/lib/borg/assimilation/*.log";
              };
            }
          ];
        }
      ];
    };
  };
  
  # Backup repository
  services.borgbackup.jobs = {
    hive-backup = {
      paths = [
        "/var/lib/borg"
        "/var/lib/cockroach"
        "/etc/borg"
      ];
      exclude = [
        "*.tmp"
      ];
      repo = "/var/lib/backups/hive";
      encryption = {
        mode = "repokey";
        passCommand = "cat /etc/borg/backup-passphrase";
      };
      compression = "auto,lzma";
      startAt = "daily";
    };
  };
  
  # User configuration
  users.users.borg = {
    isNormalUser = true;
    description = "Borg Drone Operator";
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "resistance-is-futile";
  };
  
  # Create required directories
  system.activationScripts.borgDirectories = ''
    mkdir -p /var/lib/borg/collective
    mkdir -p /var/lib/borg/assimilation
    mkdir -p /var/lib/borg/adaptation
    mkdir -p /var/lib/borg/models
    mkdir -p /var/lib/borg/data
    mkdir -p /var/lib/borg/quarantine
    mkdir -p /var/lib/backups/hive
    mkdir -p /etc/borg
    
    # Create backup passphrase if it doesn't exist
    if [ ! -f /etc/borg/backup-passphrase ]; then
      tr -dc A-Za-z0-9 < /dev/urandom | head -c 32 > /etc/borg/backup-passphrase
      chmod 600 /etc/borg/backup-passphrase
    fi
    
    chown -R borg:borg /var/lib/borg
    chown -R borg:borg /var/lib/backups
    chown -R borg:borg /etc/borg
  '';
  
  # System state version
  system.stateVersion = "24.05";
}