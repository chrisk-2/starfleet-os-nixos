{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.network.failover-system;
in
{
  options.network.failover-system = {
    enable = mkEnableOption "Starfleet OS Network Failover System";
    
    primaryInterface = mkOption {
      type = types.str;
      default = "eth0";
      description = "Primary network interface";
    };
    
    backupInterface = mkOption {
      type = types.str;
      default = "wlan0";
      description = "Backup network interface";
    };
    
    checkInterval = mkOption {
      type = types.int;
      default = 10;
      description = "Check interval in seconds";
    };
    
    pingTarget = mkOption {
      type = types.str;
      default = "8.8.8.8";
      description = "Target to ping for connectivity check";
    };
  };

  config = mkIf cfg.enable {
    # Network configuration
    networking.interfaces = {
      ${cfg.primaryInterface} = {
        useDHCP = true;
      };
      
      ${cfg.backupInterface} = {
        useDHCP = true;
      };
    };
    
    # Network manager
    networking.networkmanager = {
      enable = true;
      
      # Connection priorities
      connectionConfig = {
        "ethernet.connection-priority" = 100;
        "wifi.connection-priority" = 50;
      };
    };
    
    # Failover service
    systemd.services.network-failover = {
      description = "Starfleet OS Network Failover Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "network-failover" ''
          #!/bin/bash
          
          PRIMARY_INTERFACE="${cfg.primaryInterface}"
          BACKUP_INTERFACE="${cfg.backupInterface}"
          CHECK_INTERVAL=${toString cfg.checkInterval}
          PING_TARGET="${cfg.pingTarget}"
          
          echo "Starting Starfleet OS Network Failover Service"
          echo "Primary interface: $PRIMARY_INTERFACE"
          echo "Backup interface: $BACKUP_INTERFACE"
          echo "Check interval: $CHECK_INTERVAL seconds"
          echo "Ping target: $PING_TARGET"
          
          # Function to check if interface is up
          is_interface_up() {
            local interface=$1
            ip link show $interface | grep -q "state UP"
            return $?
          }
          
          # Function to check if interface has connectivity
          has_connectivity() {
            local interface=$1
            ping -c 1 -W 2 -I $interface $PING_TARGET > /dev/null 2>&1
            return $?
          }
          
          # Function to activate interface
          activate_interface() {
            local interface=$1
            echo "Activating interface $interface"
            ip link set $interface up
            dhclient -v $interface
          }
          
          # Function to set default route
          set_default_route() {
            local interface=$1
            local gateway=$(ip route | grep "default via" | grep $interface | awk '{print $3}')
            
            if [ -n "$gateway" ]; then
              echo "Setting default route via $gateway on $interface"
              ip route replace default via $gateway dev $interface
            else
              echo "No gateway found for $interface"
            fi
          }
          
          # Main loop
          while true; do
            # Check primary interface
            if is_interface_up $PRIMARY_INTERFACE && has_connectivity $PRIMARY_INTERFACE; then
              echo "$(date): Primary interface $PRIMARY_INTERFACE is up and has connectivity"
              set_default_route $PRIMARY_INTERFACE
            else
              echo "$(date): Primary interface $PRIMARY_INTERFACE is down or has no connectivity"
              
              # Check backup interface
              if is_interface_up $BACKUP_INTERFACE && has_connectivity $BACKUP_INTERFACE; then
                echo "$(date): Backup interface $BACKUP_INTERFACE is up and has connectivity"
                set_default_route $BACKUP_INTERFACE
              else
                echo "$(date): Backup interface $BACKUP_INTERFACE is down or has no connectivity"
                
                # Try to activate primary interface
                echo "$(date): Trying to activate primary interface $PRIMARY_INTERFACE"
                activate_interface $PRIMARY_INTERFACE
                
                # If primary still down, try backup
                if ! is_interface_up $PRIMARY_INTERFACE || ! has_connectivity $PRIMARY_INTERFACE; then
                  echo "$(date): Trying to activate backup interface $BACKUP_INTERFACE"
                  activate_interface $BACKUP_INTERFACE
                fi
              fi
            fi
            
            # Wait before next check
            sleep $CHECK_INTERVAL
          done
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Network monitoring service
    systemd.services.network-monitor = {
      description = "Starfleet OS Network Monitoring Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "network-monitor" ''
          #!/bin/bash
          
          PRIMARY_INTERFACE="${cfg.primaryInterface}"
          BACKUP_INTERFACE="${cfg.backupInterface}"
          CHECK_INTERVAL=${toString cfg.checkInterval}
          PING_TARGET="${cfg.pingTarget}"
          LOG_FILE="/var/log/network-monitor.log"
          
          echo "Starting Starfleet OS Network Monitoring Service"
          
          # Create log file
          touch $LOG_FILE
          
          # Main loop
          while true; do
            # Get interface status
            PRIMARY_STATUS=$(ip -br link show $PRIMARY_INTERFACE | awk '{print $2}')
            BACKUP_STATUS=$(ip -br link show $BACKUP_INTERFACE | awk '{print $2}')
            
            # Get IP addresses
            PRIMARY_IP=$(ip -br addr show $PRIMARY_INTERFACE | awk '{print $3}')
            BACKUP_IP=$(ip -br addr show $BACKUP_INTERFACE | awk '{print $3}')
            
            # Check connectivity
            if ping -c 1 -W 2 -I $PRIMARY_INTERFACE $PING_TARGET > /dev/null 2>&1; then
              PRIMARY_CONN="UP"
            else
              PRIMARY_CONN="DOWN"
            fi
            
            if ping -c 1 -W 2 -I $BACKUP_INTERFACE $PING_TARGET > /dev/null 2>&1; then
              BACKUP_CONN="UP"
            else
              BACKUP_CONN="DOWN"
            fi
            
            # Get default route
            DEFAULT_ROUTE=$(ip route | grep "default" | awk '{print $5}')
            
            # Log status
            echo "$(date) - PRIMARY: $PRIMARY_STATUS $PRIMARY_IP $PRIMARY_CONN, BACKUP: $BACKUP_STATUS $BACKUP_IP $BACKUP_CONN, DEFAULT: $DEFAULT_ROUTE" >> $LOG_FILE
            
            # Wait before next check
            sleep $CHECK_INTERVAL
          done
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Network tools
    environment.systemPackages = with pkgs; [
      iproute2
      dhcpcd
      wpa_supplicant
      wirelesstools
      iw
      ethtool
      tcpdump
      traceroute
      mtr
      
      # Helper scripts
      (writeScriptBin "failover-status" ''
        #!/bin/bash
        echo "Starfleet OS Network Failover Status"
        echo "=================================="
        
        echo "Primary interface (${cfg.primaryInterface}):"
        ip -br addr show ${cfg.primaryInterface}
        
        echo ""
        echo "Backup interface (${cfg.backupInterface}):"
        ip -br addr show ${cfg.backupInterface}
        
        echo ""
        echo "Default route:"
        ip route | grep "default"
        
        echo ""
        echo "Connectivity test:"
        echo "Primary: "
        ping -c 1 -W 2 -I ${cfg.primaryInterface} ${cfg.pingTarget} && echo "UP" || echo "DOWN"
        
        echo "Backup: "
        ping -c 1 -W 2 -I ${cfg.backupInterface} ${cfg.pingTarget} && echo "UP" || echo "DOWN"
        
        echo ""
        echo "Failover service:"
        systemctl status network-failover
        
        echo ""
        echo "Recent logs:"
        tail -n 10 /var/log/network-monitor.log
      '')
      
      (writeScriptBin "failover-test" ''
        #!/bin/bash
        echo "Starfleet OS Network Failover Test"
        echo "==============================="
        
        echo "This will simulate a failure on the primary interface."
        echo "Press Ctrl+C to cancel or Enter to continue..."
        read
        
        echo "Disabling primary interface (${cfg.primaryInterface})..."
        ip link set ${cfg.primaryInterface} down
        
        echo "Waiting for failover..."
        sleep 5
        
        echo "Current network status:"
        ip -br addr
        echo ""
        echo "Default route:"
        ip route | grep "default"
        
        echo ""
        echo "Press Enter to restore primary interface..."
        read
        
        echo "Enabling primary interface (${cfg.primaryInterface})..."
        ip link set ${cfg.primaryInterface} up
        
        echo "Waiting for failover..."
        sleep 5
        
        echo "Current network status:"
        ip -br addr
        echo ""
        echo "Default route:"
        ip route | grep "default"
      '')
    ];
  };
}