{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.collective-manager;
in
{
  options.services.borg.collective-manager = {
    enable = mkEnableOption "Borg Collective Manager";
    
    role = mkOption {
      type = types.enum [ "queen" "drone" "edge" "assimilator" ];
      default = "drone";
      description = "Node role in the collective";
    };
    
    droneId = mkOption {
      type = types.str;
      default = "auto";
      description = "Unique identifier for this drone";
    };
    
    queenAddress = mkOption {
      type = types.str;
      default = "10.42.0.1";
      description = "Address of the Queen node";
    };
    
    adaptationLevel = mkOption {
      type = types.enum [ "low" "medium" "high" "maximum" ];
      default = "medium";
      description = "Level of autonomous adaptation";
    };
    
    regenerationEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic service regeneration";
    };
    
    collectiveAwareness = mkOption {
      type = types.bool;
      default = true;
      description = "Enable awareness of other drones in the collective";
    };
    
    drones = mkOption {
      type = types.listOf (types.submodule {
        options = {
          id = mkOption {
            type = types.str;
            description = "Drone identifier";
          };
          
          address = mkOption {
            type = types.str;
            description = "Drone address";
          };
          
          role = mkOption {
            type = types.enum [ "drone" "edge" "assimilator" ];
            default = "drone";
            description = "Drone role";
          };
        };
      });
      default = [];
      description = "List of drones in the collective";
    };
    
    # Virtualization integration options
    virtualizationEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable virtualization integration";
    };
    
    virtualizationSystem = mkOption {
      type = types.str;
      default = "proxmox";
      description = "Virtualization system to use";
    };
    
    virtualizationEndpoint = mkOption {
      type = types.str;
      default = "";
      description = "Endpoint for virtualization API";
    };
    
    vmTemplates = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          id = mkOption {
            type = types.int;
            description = "Template ID";
          };
          
          name = mkOption {
            type = types.str;
            description = "Template name";
          };
          
          description = mkOption {
            type = types.str;
            default = "";
            description = "Template description";
          };
        };
      });
      default = {};
      description = "VM templates";
    };
    
    # Storage integration options
    storageEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable distributed storage integration";
    };
    
    storageSystem = mkOption {
      type = types.str;
      default = "ceph";
      description = "Storage system to use";
    };
    
    storagePools = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          type = mkOption {
            type = types.str;
            description = "Pool type";
          };
          
          size = mkOption {
            type = types.str;
            description = "Pool size";
          };
          
          replicas = mkOption {
            type = types.int;
            default = 2;
            description = "Number of replicas";
          };
        };
      });
      default = {};
      description = "Storage pools";
    };
    
    distributedStorage = mkOption {
      type = types.submodule {
        options = {
          enabled = mkOption {
            type = types.bool;
            default = false;
            description = "Enable distributed storage";
          };
          
          type = mkOption {
            type = types.str;
            default = "ceph";
            description = "Type of distributed storage";
          };
          
          mountPoints = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Mount points for distributed storage";
          };
        };
      };
      default = {};
      description = "Distributed storage configuration";
    };
    
    # Orchestration integration options
    orchestrationEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable container orchestration integration";
    };
    
    orchestrationSystem = mkOption {
      type = types.str;
      default = "kubernetes";
      description = "Orchestration system to use";
    };
    
    orchestrationEndpoint = mkOption {
      type = types.str;
      default = "";
      description = "Endpoint for orchestration API";
    };
    
    kubeconfig = mkOption {
      type = types.str;
      default = "";
      description = "Path to kubeconfig file";
    };
    
    # Service discovery integration options
    discoveryEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable service discovery integration";
    };
    
    discoverySystem = mkOption {
      type = types.str;
      default = "consul";
      description = "Service discovery system to use";
    };
    
    discoveryEndpoint = mkOption {
      type = types.str;
      default = "";
      description = "Endpoint for service discovery API";
    };
    
    registeredServices = mkOption {
      type = types.attrs;
      default = {};
      description = "Services registered with service discovery";
    };
    
    # Sensor integration options
    sensorIntegration = mkOption {
      type = types.submodule {
        options = {
          enabled = mkOption {
            type = types.bool;
            default = false;
            description = "Enable sensor integration";
          };
          
          type = mkOption {
            type = types.str;
            default = "home-assistant";
            description = "Sensor integration type";
          };
          
          endpoint = mkOption {
            type = types.str;
            default = "";
            description = "Endpoint for sensor integration API";
          };
          
          token = mkOption {
            type = types.str;
            default = "";
            description = "Authentication token for sensor integration";
          };
        };
      };
      default = {};
      description = "Sensor integration configuration";
    };
    
    # MQTT integration options
    mqttEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable MQTT integration";
    };
    
    mqttBroker = mkOption {
      type = types.str;
      default = "localhost";
      description = "MQTT broker address";
    };
    
    mqttPort = mkOption {
      type = types.int;
      default = 1883;
      description = "MQTT broker port";
    };
    
    mqttTopics = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "MQTT topics to subscribe to";
    };
    
    # API configuration
    apiEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Collective Manager API";
    };
    
    apiPort = mkOption {
      type = types.int;
      default = 8080;
      description = "Collective Manager API port";
    };
    
    apiAuth = mkOption {
      type = types.bool;
      default = false;
      description = "Enable API authentication";
    };
    
    apiToken = mkOption {
      type = types.str;
      default = "";
      description = "API authentication token";
    };
  };

  config = mkIf cfg.enable {
    # Collective manager service
    systemd.services.borg-collective-manager = {
      description = "Borg Collective Manager";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-collective-manager}/bin/collective-manager";
        Restart = "always";
        RestartSec = 5;
      };
      
      environment = {
        # Basic configuration
        BORG_ROLE = cfg.role;
        BORG_DRONE_ID = cfg.droneId;
        BORG_QUEEN_ADDRESS = cfg.queenAddress;
        BORG_ADAPTATION_LEVEL = cfg.adaptationLevel;
        BORG_REGENERATION = if cfg.regenerationEnabled then "true" else "false";
        BORG_COLLECTIVE_AWARENESS = if cfg.collectiveAwareness then "true" else "false";
        
        # API configuration
        BORG_API_ENABLED = if cfg.apiEnabled then "true" else "false";
        BORG_API_PORT = toString cfg.apiPort;
        BORG_API_AUTH = if cfg.apiAuth then "true" else "false";
        BORG_API_TOKEN = cfg.apiToken;
        
        # Virtualization integration
        VIRTUALIZATION_ENABLED = toString cfg.virtualizationEnabled;
        VIRTUALIZATION_SYSTEM = cfg.virtualizationSystem;
        VIRTUALIZATION_ENDPOINT = cfg.virtualizationEndpoint;
        VM_TEMPLATES = builtins.toJSON cfg.vmTemplates;
        
        # Storage integration
        STORAGE_ENABLED = toString cfg.storageEnabled;
        STORAGE_SYSTEM = cfg.storageSystem;
        STORAGE_POOLS = builtins.toJSON cfg.storagePools;
        DISTRIBUTED_STORAGE_ENABLED = toString cfg.distributedStorage.enabled;
        DISTRIBUTED_STORAGE_TYPE = cfg.distributedStorage.type;
        DISTRIBUTED_STORAGE_MOUNTPOINTS = builtins.toJSON cfg.distributedStorage.mountPoints;
        
        # Orchestration integration
        ORCHESTRATION_ENABLED = toString cfg.orchestrationEnabled;
        ORCHESTRATION_SYSTEM = cfg.orchestrationSystem;
        ORCHESTRATION_ENDPOINT = cfg.orchestrationEndpoint;
        KUBECONFIG = cfg.kubeconfig;
        
        # Discovery integration
        DISCOVERY_ENABLED = toString cfg.discoveryEnabled;
        DISCOVERY_SYSTEM = cfg.discoverySystem;
        DISCOVERY_ENDPOINT = cfg.discoveryEndpoint;
        REGISTERED_SERVICES = builtins.toJSON cfg.registeredServices;
        
        # Sensor integration
        SENSOR_INTEGRATION_ENABLED = toString cfg.sensorIntegration.enabled;
        SENSOR_INTEGRATION_TYPE = cfg.sensorIntegration.type;
        SENSOR_INTEGRATION_ENDPOINT = cfg.sensorIntegration.endpoint;
        SENSOR_INTEGRATION_TOKEN = cfg.sensorIntegration.token;
        
        # MQTT integration
        MQTT_ENABLED = toString cfg.mqttEnabled;
        MQTT_BROKER = cfg.mqttBroker;
        MQTT_PORT = toString cfg.mqttPort;
        MQTT_TOPICS = concatStringsSep "," cfg.mqttTopics;
      };
    };
    
    # Create borg user and group
    users.groups.borg = {};
    users.users.borg = {
      isSystemUser = true;
      group = "borg";
      description = "Borg Collective Manager user";
    };
    
    # Required packages
    environment.systemPackages = with pkgs; [
      borg-collective-cli
    ];
    
    # Configuration files
    environment.etc."borg/collective.conf" = {
      text = ''
        # Borg Collective Configuration
        role = ${cfg.role}
        drone_id = ${cfg.droneId}
        queen_address = ${cfg.queenAddress}
        adaptation_level = ${cfg.adaptationLevel}
        regeneration_enabled = ${if cfg.regenerationEnabled then "true" else "false"}
        collective_awareness = ${if cfg.collectiveAwareness then "true" else "false"}
        
        # API configuration
        api_enabled = ${if cfg.apiEnabled then "true" else "false"}
        api_port = ${toString cfg.apiPort}
        api_auth = ${if cfg.apiAuth then "true" else "false"}
        
        # Virtualization integration
        virtualization_enabled = ${if cfg.virtualizationEnabled then "true" else "false"}
        virtualization_system = ${cfg.virtualizationSystem}
        virtualization_endpoint = ${cfg.virtualizationEndpoint}
        
        # Storage integration
        storage_enabled = ${if cfg.storageEnabled then "true" else "false"}
        storage_system = ${cfg.storageSystem}
        
        # Orchestration integration
        orchestration_enabled = ${if cfg.orchestrationEnabled then "true" else "false"}
        orchestration_system = ${cfg.orchestrationSystem}
        orchestration_endpoint = ${cfg.orchestrationEndpoint}
        
        # Discovery integration
        discovery_enabled = ${if cfg.discoveryEnabled then "true" else "false"}
        discovery_system = ${cfg.discoverySystem}
        discovery_endpoint = ${cfg.discoveryEndpoint}
        
        # Sensor integration
        sensor_integration_enabled = ${if cfg.sensorIntegration.enabled then "true" else "false"}
        sensor_integration_type = ${cfg.sensorIntegration.type}
        sensor_integration_endpoint = ${cfg.sensorIntegration.endpoint}
        
        # MQTT integration
        mqtt_enabled = ${if cfg.mqttEnabled then "true" else "false"}
        mqtt_broker = ${cfg.mqttBroker}
        mqtt_port = ${toString cfg.mqttPort}
        mqtt_topics = ${concatStringsSep "," cfg.mqttTopics}
      '';
    };
    
    # Drones configuration file
    environment.etc."borg/drones.conf" = mkIf (cfg.role == "queen" && cfg.drones != []) {
      text = concatMapStrings (drone: ''
        [drone.${drone.id}]
        address = ${drone.address}
        role = ${drone.role}
        
      '') cfg.drones;
    };
    
    # Collective status service
    systemd.services.borg-collective-status = {
      description = "Borg Collective Status Monitor";
      wantedBy = [ "multi-user.target" ];
      after = [ "borg-collective-manager.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-collective-manager}/bin/collective-status";
        Restart = "always";
        RestartSec = 30;
      };
      
      environment = {
        BORG_ROLE = cfg.role;
        BORG_DRONE_ID = cfg.droneId;
        BORG_QUEEN_ADDRESS = cfg.queenAddress;
      };
    };
    
    # Collective health check
    systemd.services.borg-collective-health = {
      description = "Borg Collective Health Check";
      startAt = "*:0/5";
      
      serviceConfig = {
        Type = "oneshot";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-collective-manager}/bin/collective-health";
      };
      
      environment = {
        BORG_ROLE = cfg.role;
        BORG_DRONE_ID = cfg.droneId;
        BORG_QUEEN_ADDRESS = cfg.queenAddress;
      };
    };
    
    # API service
    systemd.services.borg-collective-api = mkIf cfg.apiEnabled {
      description = "Borg Collective API";
      wantedBy = [ "multi-user.target" ];
      after = [ "borg-collective-manager.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-collective-manager}/bin/collective-api";
        Restart = "always";
        RestartSec = 5;
      };
      
      environment = {
        BORG_API_PORT = toString cfg.apiPort;
        BORG_API_AUTH = if cfg.apiAuth then "true" else "false";
        BORG_API_TOKEN = cfg.apiToken;
      };
    };
    
    # Prometheus metrics
    services.prometheus.exporters.borg-collective = {
      enable = true;
      port = 9694;
      openFirewall = true;
    };
    
    # Firewall configuration
    networking.firewall.allowedTCPPorts = [
      9694  # Prometheus exporter
      7777  # Collective communication
      cfg.apiPort  # API port
    ];
    
    # Register with service discovery if enabled
    services.borg.discovery.registry.services = mkIf (cfg.discoveryEnabled && config.services.borg.discovery.registry.enable) {
      "borg-collective-manager" = {
        name = "borg-collective-manager";
        tags = [ "borg" "collective" cfg.role ];
        address = config.networking.hostName;
        port = cfg.apiPort;
        checks = [
          {
            type = "http";
            target = "http://localhost:${toString cfg.apiPort}/health";
            interval = "30s";
          }
        ];
      };
    };
  };
}