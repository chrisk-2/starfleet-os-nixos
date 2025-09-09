{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.network.tunnel-service;
in
{
  options.network.tunnel-service = {
    enable = mkEnableOption "Starfleet OS Secure Tunnel Service";
    
    tunnelType = mkOption {
      type = types.enum [ "wireguard" "openvpn" "ssh" "tor" ];
      default = "wireguard";
      description = "Type of tunnel to use";
    };
    
    serverAddress = mkOption {
      type = types.str;
      default = "uss-enterprise-bridge";
      description = "Tunnel server address";
    };
    
    serverPort = mkOption {
      type = types.int;
      default = 51820;
      description = "Tunnel server port";
    };
    
    localPort = mkOption {
      type = types.int;
      default = 51825;
      description = "Local port for tunnel";
    };
    
    autoConnect = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically connect to tunnel on startup";
    };
  };

  config = mkIf cfg.enable {
    # WireGuard tunnel
    networking.wireguard.interfaces = mkIf (cfg.tunnelType == "wireguard") {
      wg0 = {
        ips = [ "10.42.0.5/24" ];
        listenPort = cfg.localPort;
        privateKeyFile = "/etc/wireguard/private.key";
        
        peers = [
          {
            publicKey = "server-public-key";  # Replace with actual public key
            allowedIPs = [ "10.42.0.0/24" ];
            endpoint = "${cfg.serverAddress}:${toString cfg.serverPort}";
            persistentKeepalive = 25;
          }
        ];
      };
    };
    
    # OpenVPN tunnel
    services.openvpn.servers = mkIf (cfg.tunnelType == "openvpn") {
      starfleet = {
        config = ''
          client
          dev tun
          proto udp
          remote ${cfg.serverAddress} ${toString cfg.serverPort}
          resolv-retry infinite
          nobind
          persist-key
          persist-tun
          ca /etc/openvpn/ca.crt
          cert /etc/openvpn/client.crt
          key /etc/openvpn/client.key
          remote-cert-tls server
          cipher AES-256-GCM
          auth SHA512
          verb 3
        '';
        autoStart = cfg.autoConnect;
      };
    };
    
    # SSH tunnel
    systemd.services.ssh-tunnel = mkIf (cfg.tunnelType == "ssh") {
      description = "SSH Tunnel Service";
      wantedBy = mkIf cfg.autoConnect [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.openssh}/bin/ssh -N -T -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -L ${toString cfg.localPort}:localhost:${toString cfg.serverPort} starfleet@${cfg.serverAddress}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Tor tunnel
    services.tor = mkIf (cfg.tunnelType == "tor") {
      enable = true;
      client.enable = true;
      
      settings = {
        ClientOnly = true;
        SocksPort = cfg.localPort;
        ControlPort = cfg.localPort + 1;
      };
    };
    
    # Key generation service
    systemd.services.tunnel-key-generation = {
      description = "Generate tunnel keys";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      before = mkIf (cfg.tunnelType == "wireguard") [ "wireguard-wg0.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      
      script = ''
        # Generate keys based on tunnel type
        case "${cfg.tunnelType}" in
          "wireguard")
            if [ ! -f /etc/wireguard/private.key ]; then
              mkdir -p /etc/wireguard
              chmod 700 /etc/wireguard
              ${pkgs.wireguard-tools}/bin/wg genkey > /etc/wireguard/private.key
              chmod 600 /etc/wireguard/private.key
              ${pkgs.wireguard-tools}/bin/wg pubkey < /etc/wireguard/private.key > /etc/wireguard/public.key
            fi
            ;;
          "openvpn")
            # OpenVPN keys would typically be provided externally
            mkdir -p /etc/openvpn
            chmod 700 /etc/openvpn
            ;;
          "ssh")
            if [ ! -f /home/starfleet/.ssh/id_ed25519 ]; then
              mkdir -p /home/starfleet/.ssh
              chmod 700 /home/starfleet/.ssh
              ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f /home/starfleet/.ssh/id_ed25519 -N ""
              chown -R starfleet:starfleet /home/starfleet/.ssh
            fi
            ;;
          "tor")
            # Tor doesn't need key generation
            ;;
        esac
      '';
    };
    
    # Tunnel status service
    systemd.services.tunnel-status-monitor = {
      description = "Tunnel Status Monitor";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "tunnel-status-monitor" ''
          #!/bin/bash
          
          TUNNEL_TYPE="${cfg.tunnelType}"
          SERVER_ADDRESS="${cfg.serverAddress}"
          SERVER_PORT=${toString cfg.serverPort}
          LOCAL_PORT=${toString cfg.localPort}
          CHECK_INTERVAL=60
          
          echo "Starting Starfleet OS Tunnel Status Monitor"
          echo "Tunnel type: $TUNNEL_TYPE"
          echo "Server: $SERVER_ADDRESS:$SERVER_PORT"
          echo "Local port: $LOCAL_PORT"
          
          # Function to check tunnel status
          check_tunnel() {
            case "$TUNNEL_TYPE" in
              "wireguard")
                ${pkgs.wireguard-tools}/bin/wg show wg0 | grep -q "latest handshake"
                return $?
                ;;
              "openvpn")
                ${pkgs.iproute2}/bin/ip link show tun0 | grep -q "UP"
                return $?
                ;;
              "ssh")
                ${pkgs.procps}/bin/pgrep -f "ssh -N -T.*$SERVER_ADDRESS" > /dev/null
                return $?
                ;;
              "tor")
                ${pkgs.netcat}/bin/nc -z localhost $LOCAL_PORT
                return $?
                ;;
            esac
          }
          
          # Function to restart tunnel
          restart_tunnel() {
            case "$TUNNEL_TYPE" in
              "wireguard")
                systemctl restart wireguard-wg0
                ;;
              "openvpn")
                systemctl restart openvpn-starfleet
                ;;
              "ssh")
                systemctl restart ssh-tunnel
                ;;
              "tor")
                systemctl restart tor
                ;;
            esac
          }
          
          # Main loop
          while true; do
            if check_tunnel; then
              echo "$(date): Tunnel is UP"
            else
              echo "$(date): Tunnel is DOWN, restarting..."
              restart_tunnel
            fi
            
            sleep $CHECK_INTERVAL
          done
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Tunnel tools
    environment.systemPackages = with pkgs; [
      # Common tools
      iproute2
      tcpdump
      netcat
      
      # Tunnel-specific tools
      (if cfg.tunnelType == "wireguard" then wireguard-tools else null)
      (if cfg.tunnelType == "openvpn" then openvpn else null)
      (if cfg.tunnelType == "ssh" then openssh else null)
      (if cfg.tunnelType == "tor" then tor else null)
      
      # Helper scripts
      (writeScriptBin "tunnel-status" ''
        #!/bin/bash
        echo "Starfleet OS Tunnel Status"
        echo "========================="
        
        TUNNEL_TYPE="${cfg.tunnelType}"
        
        echo "Tunnel type: $TUNNEL_TYPE"
        echo "Server: ${cfg.serverAddress}:${toString cfg.serverPort}"
        echo "Local port: ${toString cfg.localPort}"
        
        case "$TUNNEL_TYPE" in
          "wireguard")
            echo ""
            echo "WireGuard status:"
            ${wireguard-tools}/bin/wg show wg0
            ;;
          "openvpn")
            echo ""
            echo "OpenVPN status:"
            systemctl status openvpn-starfleet
            ${iproute2}/bin/ip link show tun0
            ;;
          "ssh")
            echo ""
            echo "SSH tunnel status:"
            systemctl status ssh-tunnel
            ${procps}/bin/pgrep -fa "ssh -N -T.*${cfg.serverAddress}"
            ;;
          "tor")
            echo ""
            echo "Tor status:"
            systemctl status tor
            ${netcat}/bin/nc -z localhost ${toString cfg.localPort} && echo "Tor SOCKS proxy is UP" || echo "Tor SOCKS proxy is DOWN"
            ;;
        esac
        
        echo ""
        echo "Connection test:"
        ping -c 3 ${cfg.serverAddress} || echo "Cannot reach server"
      '')
      
      (writeScriptBin "tunnel-connect" ''
        #!/bin/bash
        echo "Connecting to tunnel..."
        
        TUNNEL_TYPE="${cfg.tunnelType}"
        
        case "$TUNNEL_TYPE" in
          "wireguard")
            systemctl start wireguard-wg0
            ;;
          "openvpn")
            systemctl start openvpn-starfleet
            ;;
          "ssh")
            systemctl start ssh-tunnel
            ;;
          "tor")
            systemctl start tor
            ;;
        esac
        
        echo "Tunnel connection initiated"
        sleep 2
        tunnel-status
      '')
      
      (writeScriptBin "tunnel-disconnect" ''
        #!/bin/bash
        echo "Disconnecting from tunnel..."
        
        TUNNEL_TYPE="${cfg.tunnelType}"
        
        case "$TUNNEL_TYPE" in
          "wireguard")
            systemctl stop wireguard-wg0
            ;;
          "openvpn")
            systemctl stop openvpn-starfleet
            ;;
          "ssh")
            systemctl stop ssh-tunnel
            ;;
          "tor")
            systemctl stop tor
            ;;
        esac
        
        echo "Tunnel disconnected"
      '')
    ];
  };
}