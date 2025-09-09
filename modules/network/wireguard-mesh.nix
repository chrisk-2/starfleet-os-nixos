{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.network.wireguard-mesh;
  
  nodeRoles = {
    bridge = {
      hostname = "uss-enterprise-bridge";
      ip = "10.42.0.1";
      port = 51820;
      publicKey = "bridge-public-key";
      allowedIPs = [ "10.42.0.1/32" ];
    };
    
    drone-a = {
      hostname = "borg-drone-alpha";
      ip = "10.42.0.2";
      port = 51821;
      publicKey = "drone-a-public-key";
      allowedIPs = [ "10.42.0.2/32" ];
    };
    
    drone-b = {
      hostname = "borg-drone-beta";
      ip = "10.42.0.3";
      port = 51822;
      publicKey = "drone-b-public-key";
      allowedIPs = [ "10.42.0.3/32" ];
    };
    
    edge-pi = {
      hostname = "edge-sensor-drone";
      ip = "10.42.0.4";
      port = 51823;
      publicKey = "edge-pi-public-key";
      allowedIPs = [ "10.42.0.4/32" ];
    };
    
    portable = {
      hostname = "mobile-assimilation-unit";
      ip = "10.42.0.5";
      port = 51824;
      publicKey = "portable-public-key";
      allowedIPs = [ "10.42.0.5/32" ];
    };
  };
  
in
{
  options.network.wireguard-mesh = {
    enable = mkEnableOption "Starfleet OS WireGuard mesh networking";
    
    nodeRole = mkOption {
      type = types.enum [ "bridge" "drone-a" "drone-b" "edge-pi" "portable" ];
      default = "bridge";
      description = "Node role in the mesh network";
    };
    
    enableMeshDiscovery = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic mesh discovery";
    };
    
    enableFailover = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic failover";
    };
    
    encryptionLevel = mkOption {
      type = types.enum [ "standard" "high" "maximum" ];
      default = "high";
      description = "Encryption level for mesh traffic";
    };
  };

  config = mkIf cfg.enable {
    # WireGuard configuration
    networking.wireguard.enable = true;
    
    networking.wg-quick.interfaces.starfleet-mesh = {
      address = [ "${nodeRoles.${cfg.nodeRole}.ip}/24" ];
      listenPort = nodeRoles.${cfg.nodeRole}.port;
      privateKeyFile = "/etc/wireguard/starfleet-mesh.key";
      
      peers = mapAttrsToList (name: node: {
        publicKey = node.publicKey;
        allowedIPs = node.allowedIPs;
        endpoint = "${node.hostname}:${toString node.port}";
        persistentKeepalive = 25;
      }) (filterAttrs (n: v: n != cfg.nodeRole) nodeRoles);
      
      postUp = ''
        # Starfleet OS mesh initialization
        echo "Starfleet mesh network initialized for ${cfg.nodeRole}"
        
        # Route configuration
        ip route add 10.42.0.0/24 dev starfleet-mesh
        ip route add 10.42.0.0/16 via 10.42.0.1
        
        # Firewall rules
        iptables -A FORWARD -i starfleet-mesh -j ACCEPT
        iptables -A FORWARD -o starfleet-mesh -j ACCEPT
        
        # NAT rules for internet access
        iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      '';
      
      postDown = ''
        # Cleanup routes
        ip route del 10.42.0.0/24 dev starfleet-mesh
        iptables -D FORWARD -i starfleet-mesh -j ACCEPT
        iptables -D FORWARD -o starfleet-mesh -j ACCEPT
      '';
    };
    
    # Network services
    services.dnsmasq = {
      enable = true;
      settings = {
        server = [ "10.42.0.1" ];
        domain = "starfleet.local";
        "expand-hosts" = true;
        "domain-needed" = true;
        "bogus-priv" = true;
        "local" = "/starfleet.local/";
        "address" = [
          "/bridge.starfleet.local/10.42.0.1"
          "/drone-a.starfleet.local/10.42.0.2"
          "/drone-b.starfleet.local/10.42.0.3"
          "/edge-pi.starfleet.local/10.42.0.4"
          "/portable.starfleet.local/10.42.0.5"
        ];
      };
    };
    
    # Service discovery
    systemd.services.mesh-discovery = {
      description = "Starfleet OS Mesh Discovery";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.callPackage ./mesh-discovery.nix { }}/bin/mesh-discovery";
        Restart = "always";
      };
      
      environment = {
        NODE_ROLE = cfg.nodeRole;
        MESH_PREFIX = "10.42.0";
        DISCOVERY_PORT = "5353";
      };
    };
    
    # Health monitoring
    systemd.services.mesh-health = {
      description = "Starfleet OS Mesh Health Monitor";
      wantedBy = [ "multi-user.target" ];
      after = [ "mesh-discovery.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.callPackage ./mesh-health.nix { }}/bin/mesh-health";
        Restart = "always";
      };
    };
    
    # Failover system
    systemd.services.mesh-failover = {
      description = "Starfleet OS Mesh Failover";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.callPackage ./mesh-failover.nix { }}/bin/mesh-failover";
        Restart = "always";
      };
      
      environment = {
        ENABLE_FAILOVER = if cfg.enableFailover then "true" else "false";
      };
    };
    
    # Network configuration
    networking.firewall = {
      allowedTCPPorts = [
        51820  # WireGuard
        51821
        51822
        51823
        51824
        5353   # Service discovery
        8080   # Web interface
      ];
      
      allowedUDPPorts = [
        51820  # WireGuard
        51821
        51822
        51823
        51824
        5353   # Service discovery
      ];
    };
    
    # Network tools
    environment.systemPackages = with pkgs; [
      iperf3
      nmap
      tcpdump
      wireshark
      netcat
      socat
    ];
    
    # Configuration files
    environment.etc."starfleet/mesh.json" = {
      text = builtins.toJSON {
        nodeRoles = nodeRoles;
        currentNode = cfg.nodeRole;
        encryption = cfg.encryptionLevel;
        services = {
          discovery = cfg.enableMeshDiscovery;
          failover = cfg.enableFailover;
          health = true;
        };
      };
    };
    
    # Mesh status tool
    environment.systemPackages = with pkgs; [
      (writeScriptBin "starfleet-mesh-status" ''
        #!/bin/bash
        echo "Starfleet OS Mesh Network Status"
        echo "==============================="
        echo "Node Role: ${cfg.nodeRole}"
        echo "IP Address: ${nodeRoles.${cfg.nodeRole}.ip}"
        echo "Encryption: ${cfg.encryptionLevel}"
        echo ""
        
        echo "Active Connections:"
        wg show starfleet-mesh
        
        echo ""
        echo "Service Discovery:"
        systemctl status mesh-discovery
        
        echo ""
        echo "Health Status:"
        systemctl status mesh-health
      '')
      
      (writeScriptBin "starfleet-mesh-join" ''
        #!/bin/bash
        echo "Joining Starfleet mesh network..."
        
        if [ "$#" -ne 2 ]; then
          echo "Usage: starfleet-mesh-join <role> <endpoint>"
          exit 1
        fi
        
        ROLE=$1
        ENDPOINT=$2
        
        # Generate WireGuard keys
        umask 077
        wg genkey | tee /etc/wireguard/starfleet-mesh.key | wg pubkey > /etc/wireguard/starfleet-mesh.pub
        
        echo "Generated keys for $ROLE"
        echo "Public key: $(cat /etc/wireguard/starfleet-mesh.pub)"
        
        # Restart WireGuard
        systemctl restart wg-quick-starfleet-mesh
        
        echo "Mesh network joined successfully"
      '')
    ];
  };
}