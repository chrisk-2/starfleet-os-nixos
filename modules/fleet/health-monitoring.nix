{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.fleet-health;
in
{
  options.services.fleet-health = {
    enable = mkEnableOption "Starfleet OS Fleet Health Monitoring";
    
    interval = mkOption {
      type = types.int;
      default = 60;
      description = "Monitoring interval in seconds";
    };
    
    nodes = mkOption {
      type = types.listOf types.str;
      default = [
        "uss-enterprise-bridge"
        "borg-drone-alpha"
        "borg-drone-beta"
        "edge-sensor-drone"
        "mobile-assimilation-unit"
      ];
      description = "List of nodes to monitor";
    };
    
    alertThreshold = mkOption {
      type = types.int;
      default = 3;
      description = "Number of failed checks before alerting";
    };
  };

  config = mkIf cfg.enable {
    # Fleet health monitoring service
    systemd.services.fleet-health-monitor = {
      description = "Starfleet OS Fleet Health Monitor";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.writeShellScript "fleet-health-monitor" ''
          #!/bin/bash
          
          NODES="${concatStringsSep " " cfg.nodes}"
          INTERVAL=${toString cfg.interval}
          THRESHOLD=${toString cfg.alertThreshold}
          
          declare -A failures
          
          echo "Starting Starfleet OS Fleet Health Monitor"
          echo "Monitoring nodes: $NODES"
          echo "Interval: $INTERVAL seconds"
          echo "Alert threshold: $THRESHOLD failures"
          
          while true; do
            for node in $NODES; do
              if ping -c 1 -W 2 $node > /dev/null 2>&1; then
                echo "[$(date)] Node $node is ONLINE"
                failures[$node]=0
              else
                failures[$node]=$((failures[$node] + 1))
                echo "[$(date)] Node $node is OFFLINE (${failures[$node]} failures)"
                
                if [ ${failures[$node]} -ge $THRESHOLD ]; then
                  echo "[$(date)] ALERT: Node $node has failed $THRESHOLD times"
                  # Send alert (implement your preferred alert mechanism)
                  ${pkgs.libnotify}/bin/notify-send "Starfleet Alert" "Node $node is offline!"
                fi
              fi
            done
            
            sleep $INTERVAL
          done
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Fleet health dashboard
    environment.systemPackages = with pkgs; [
      (writeScriptBin "fleet-health-dashboard" ''
        #!/bin/bash
        echo "Starfleet OS Fleet Health Dashboard"
        echo "=================================="
        
        for node in ${concatStringsSep " " cfg.nodes}; do
          echo -n "Node $node: "
          if ping -c 1 -W 2 $node > /dev/null 2>&1; then
            echo "ONLINE"
          else
            echo "OFFLINE"
          fi
        done
        
        echo ""
        echo "System Status:"
        systemctl status fleet-health-monitor
      '')
    ];
  };
}