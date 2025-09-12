{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.discovery.registry;
  
  # Define the service check type
  checkType = types.submodule {
    options = {
      type = mkOption {
        type = types.enum [ "http" "tcp" "script" "ttl" "docker" "grpc" ];
        description = "Check type";
      };
      
      target = mkOption {
        type = types.str;
        description = "Check target (URL, command, etc.)";
      };
      
      interval = mkOption {
        type = types.str;
        default = "30s";
        description = "Check interval";
      };
      
      timeout = mkOption {
        type = types.str;
        default = "5s";
        description = "Check timeout";
      };
      
      deregisterCriticalServiceAfter = mkOption {
        type = types.str;
        default = "1m";
        description = "Time after which to deregister critical service";
      };
    };
  };
  
  # Define the service type
  serviceType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Service name";
      };
      
      tags = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Service tags";
      };
      
      address = mkOption {
        type = types.str;
        description = "Service address";
      };
      
      port = mkOption {
        type = types.int;
        description = "Service port";
      };
      
      checks = mkOption {
        type = types.listOf checkType;
        default = [];
        description = "Service health checks";
      };
      
      meta = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Service metadata";
      };
      
      enableTagOverride = mkOption {
        type = types.bool;
        default = false;
        description = "Enable tag override";
      };
    };
  };
in {
  options.services.borg.discovery.registry = {
    enable = mkEnableOption "Borg Collective service registry";
    
    services = mkOption {
      type = types.attrsOf serviceType;
      default = {};
      description = "Services to register";
    };
    
    autoRegisterServices = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically register system services";
    };
    
    autoRegisterNodeExporter = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically register node exporter";
    };
    
    autoRegisterConsulExporter = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically register consul exporter";
    };
  };
  
  config = mkIf cfg.enable {
    # Ensure Consul is enabled
    services.borg.discovery.consul.enable = true;
    
    # Register services with Consul
    services.consul.extraConfig.services = mapAttrsToList (name: service: {
      inherit (service) name tags address port meta enableTagOverride;
      checks = map (check: {
        ${check.type} = check.target;
        inherit (check) interval timeout deregisterCriticalServiceAfter;
      }) service.checks;
    }) cfg.services;
    
    # Auto-register node exporter
    services.prometheus.exporters.node = mkIf cfg.autoRegisterNodeExporter {
      enable = true;
      enabledCollectors = [
        "systemd"
        "textfile"
        "filesystem"
        "diskstats"
        "meminfo"
        "netdev"
        "netstat"
        "stat"
        "time"
        "vmstat"
        "logind"
        "interrupts"
        "ksmd"
        "processes"
      ];
      openFirewall = true;
      firewallFilter = "-i lo -p tcp -m tcp --dport 9100 -j ACCEPT";
    };
    
    # Auto-register consul exporter
    services.prometheus.exporters.consul = mkIf cfg.autoRegisterConsulExporter {
      enable = true;
      openFirewall = true;
      firewallFilter = "-i lo -p tcp -m tcp --dport 9107 -j ACCEPT";
    };
    
    # Auto-register system services
    services.consul.extraConfig.services = mkIf cfg.autoRegisterServices (
      # Add node exporter service
      (optional cfg.autoRegisterNodeExporter {
        name = "node-exporter";
        tags = [ "prometheus" "metrics" "node" ];
        address = config.networking.hostName;
        port = 9100;
        checks = [
          {
            http = "http://localhost:9100/metrics";
            interval = "30s";
          }
        ];
      }) ++
      
      # Add consul exporter service
      (optional cfg.autoRegisterConsulExporter {
        name = "consul-exporter";
        tags = [ "prometheus" "metrics" "consul" ];
        address = config.networking.hostName;
        port = 9107;
        checks = [
          {
            http = "http://localhost:9107/metrics";
            interval = "30s";
          }
        ];
      }) ++
      
      # Add SSH service
      (optional config.services.openssh.enable {
        name = "ssh";
        tags = [ "system" "ssh" ];
        address = config.networking.hostName;
        port = 22;
        checks = [
          {
            tcp = "localhost:22";
            interval = "30s";
          }
        ];
      })
    );
    
    # Create service for registering custom services
    systemd.services.consul-service-registration = {
      description = "Register custom services with Consul";
      wantedBy = [ "multi-user.target" ];
      after = [ "consul.service" ];
      script = ''
        # Wait for Consul to be available
        until ${pkgs.consul}/bin/consul members &>/dev/null; do
          echo "Waiting for Consul..."
          sleep 5
        done
        
        # Register any custom services that need special handling
        # (This is a placeholder for future custom service registration logic)
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = mkIf config.services.borg.collective-manager.enable {
      registeredServices = cfg.services;
    };
  };
}