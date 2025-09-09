{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.system.watchdog;
in
{
  options.system.watchdog = {
    enable = mkEnableOption "Starfleet OS System Watchdog";
    
    interval = mkOption {
      type = types.int;
      default = 10;
      description = "Watchdog interval in seconds";
    };
    
    timeout = mkOption {
      type = types.int;
      default = 60;
      description = "Watchdog timeout in seconds";
    };
    
    enableHardwareWatchdog = mkOption {
      type = types.bool;
      default = true;
      description = "Enable hardware watchdog if available";
    };
    
    enableNetworkWatchdog = mkOption {
      type = types.bool;
      default = true;
      description = "Enable network watchdog";
    };
    
    networkTarget = mkOption {
      type = types.str;
      default = "uss-enterprise-bridge";
      description = "Network target to ping";
    };
    
    maxFailures = mkOption {
      type = types.int;
      default = 5;
      description = "Maximum number of consecutive failures before action";
    };
    
    action = mkOption {
      type = types.enum [ "reboot" "restart-network" "alert" ];
      default = "restart-network";
      description = "Action to take on watchdog trigger";
    };
  };

  config = mkIf cfg.enable {
    # Hardware watchdog
    systemd.watchdog = mkIf cfg.enableHardwareWatchdog {
      runtimeTime = "${toString cfg.timeout}s";
      rebootTime = "${toString (cfg.timeout * 2)}s";
    };
    
    # Watchdog service
    systemd.services.system-watchdog = {
      description = "Starfleet OS System Watchdog";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "system-watchdog" ''
          #!/bin/bash
          
          INTERVAL=${toString cfg.interval}
          NETWORK_TARGET="${cfg.networkTarget}"
          MAX_FAILURES=${toString cfg.maxFailures}
          ACTION="${cfg.action}"
          
          echo "Starting Starfleet OS System Watchdog"
          echo "Interval: $INTERVAL seconds"
          echo "Network target: $NETWORK_TARGET"
          echo "Max failures: $MAX_FAILURES"
          echo "Action: $ACTION"
          
          # Initialize failure counter
          failures=0
          
          # Main loop
          while true; do
            # Check network connectivity
            if ${toString cfg.enableNetworkWatchdog}; then
              if ping -c 1 -W 2 $NETWORK_TARGET > /dev/null 2>&1; then
                echo "$(date): Network check passed"
                failures=0
              else
                failures=$((failures + 1))
                echo "$(date): Network check failed ($failures/$MAX_FAILURES)"
                
                if [ $failures -ge $MAX_FAILURES ]; then
                  echo "$(date): Maximum failures reached, taking action: $ACTION"
                  
                  case "$ACTION" in
                    "reboot")
                      echo "$(date): Rebooting system"
                      /bin/systemctl reboot
                      ;;
                    "restart-network")
                      echo "$(date): Restarting network"
                      /bin/systemctl restart NetworkManager
                      failures=0
                      ;;
                    "alert")
                      echo "$(date): Sending alert"
                      ${pkgs.libnotify}/bin/notify-send "Starfleet Alert" "Network connectivity lost!"
                      ;;
                  esac
                fi
              fi
            fi
            
            # Check system health
            load=$(uptime | awk '{print $(NF-2)}' | tr -d ',')
            load_threshold=10
            
            if (( $(echo "$load > $load_threshold" | bc -l) )); then
              echo "$(date): System load is high: $load"
              # Log high load but don't take action
            fi
            
            # Check disk space
            disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
            disk_threshold=90
            
            if [ $disk_usage -gt $disk_threshold ]; then
              echo "$(date): Disk usage is high: $disk_usage%"
              # Log high disk usage but don't take action
            fi
            
            # Pat the hardware watchdog if enabled
            if ${toString cfg.enableHardwareWatchdog}; then
              if [ -e /dev/watchdog ]; then
                echo "$(date): Patting hardware watchdog"
                echo 1 > /dev/watchdog
              fi
            fi
            
            # Wait for next interval
            sleep $INTERVAL
          done
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Watchdog tools
    environment.systemPackages = with pkgs; [
      watchdog
      bc
      
      # Helper scripts
      (writeScriptBin "watchdog-status" ''
        #!/bin/bash
        echo "Starfleet OS System Watchdog Status"
        echo "================================="
        
        echo "Watchdog service:"
        systemctl status system-watchdog
        
        echo ""
        echo "Hardware watchdog:"
        if [ -e /dev/watchdog ]; then
          echo "Hardware watchdog is available"
        else
          echo "Hardware watchdog is not available"
        fi
        
        echo ""
        echo "Network connectivity:"
        ping -c 3 ${cfg.networkTarget} || echo "Network target unreachable"
        
        echo ""
        echo "System health:"
        echo "Load average: $(uptime | awk '{print $(NF-2)" "$(NF-1)" "$(NF)}' | tr -d ',')"
        echo "Memory usage: $(free -h | awk '/Mem:/ {print $3"/"$2" ("$3/$2*100"%)"}')"
        echo "Disk usage: $(df -h / | awk 'NR==2 {print $5" ("$3"/"$2")"}')"
      '')
      
      (writeScriptBin "watchdog-test" ''
        #!/bin/bash
        echo "Starfleet OS Watchdog Test"
        echo "========================="
        
        echo "This will simulate a network failure to test the watchdog."
        echo "Press Ctrl+C to cancel or Enter to continue..."
        read
        
        echo "Blocking network traffic to ${cfg.networkTarget}..."
        sudo iptables -A OUTPUT -d ${cfg.networkTarget} -j DROP
        
        echo "Waiting for watchdog to detect failure..."
        echo "This will take up to $((${toString cfg.interval} * ${toString cfg.maxFailures})) seconds"
        
        # Wait for watchdog to trigger
        sleep $((${toString cfg.interval} * ${toString cfg.maxFailures} + 5))
        
        echo "Removing network block..."
        sudo iptables -D OUTPUT -d ${cfg.networkTarget} -j DROP
        
        echo "Test complete. Check watchdog logs for results."
      '')
    ];
  };
}