{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.discovery.consul;
in {
  options.services.borg.discovery.consul = {
    enable = mkEnableOption "Borg Collective Consul integration";
    
    role = mkOption {
      type = types.enum [ "server" "client" ];
      default = "client";
      description = "Role of this node in the Consul cluster";
    };
    
    datacenter = mkOption {
      type = types.str;
      default = "borg-collective";
      description = "Consul datacenter name";
    };
    
    serverNodes = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of Consul server node addresses";
    };
    
    nodeName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Name of this node in Consul";
    };
    
    enableUi = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Consul web UI";
    };
    
    bootstrapExpect = mkOption {
      type = types.int;
      default = 1;
      description = "Number of server nodes expected in the cluster";
    };
    
    advertiseAddr = mkOption {
      type = types.str;
      default = "";
      description = "Address to advertise to other nodes";
    };
    
    encryptionKey = mkOption {
      type = types.str;
      default = "";
      description = "Encryption key for Consul gossip protocol";
    };
  };
  
  config = mkIf cfg.enable {
    # Install Consul
    services.consul = {
      enable = true;
      webUi = cfg.role == "server" && cfg.enableUi;
      extraConfig = {
        server = cfg.role == "server";
        bootstrap_expect = cfg.role == "server" ? cfg.bootstrapExpect : null;
        datacenter = cfg.datacenter;
        data_dir = "/var/lib/consul";
        bind_addr = "0.0.0.0";
        client_addr = "0.0.0.0";
        node_name = cfg.nodeName;
        retry_join = cfg.serverNodes;
        advertise_addr = cfg.advertiseAddr != "" ? cfg.advertiseAddr : null;
        encrypt = cfg.encryptionKey != "" ? cfg.encryptionKey : null;
        ui_config = {
          enabled = cfg.role == "server" && cfg.enableUi;
        };
        telemetry = {
          prometheus_retention_time = "24h";
          disable_hostname = false;
        };
        connect = {
          enabled = true;
        };
        ports = {
          grpc = 8502;
        };
        acl = {
          enabled = false;
          default_policy = "allow";
          enable_token_persistence = true;
        };
      };
    };
    
    # Configure firewall for Consul
    networking.firewall.allowedTCPPorts = [
      8300  # Server RPC
      8301  # Serf LAN
      8302  # Serf WAN
      8500  # HTTP API
      8501  # HTTPS API
      8502  # gRPC API
      8600  # DNS
    ];
    
    networking.firewall.allowedUDPPorts = [
      8301  # Serf LAN
      8302  # Serf WAN
      8600  # DNS
    ];
    
    # Install Consul tools
    environment.systemPackages = with pkgs; [
      consul
      consul-template
      jq
      curl
    ];
    
    # Create systemd service for Consul DNS integration
    systemd.services.consul-dns-integration = {
      description = "Integrate Consul DNS with system resolver";
      wantedBy = [ "multi-user.target" ];
      after = [ "consul.service" ];
      script = ''
        # Wait for Consul to be available
        until ${pkgs.consul}/bin/consul members &>/dev/null; do
          echo "Waiting for Consul..."
          sleep 5
        done
        
        # Configure DNS resolution for .consul domains
        if ! grep -q "nameserver 127.0.0.1" /etc/resolv.conf; then
          echo "nameserver 127.0.0.1" > /etc/resolv.conf.consul
          cat /etc/resolv.conf >> /etc/resolv.conf.consul
          cp /etc/resolv.conf.consul /etc/resolv.conf
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Configure systemd-resolved for Consul DNS integration
    services.resolved = {
      enable = true;
      domains = [ "~consul" ];
      fallbackDns = [ "1.1.1.1" "8.8.8.8" ];
      extraConfig = ''
        DNS=127.0.0.1:8600
        Domains=~consul
      '';
    };
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = mkIf config.services.borg.collective-manager.enable {
      discoveryEnabled = true;
      discoverySystem = "consul";
      discoveryEndpoint = "http://localhost:8500";
    };
  };
}