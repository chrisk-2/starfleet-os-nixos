{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.network.heartbeat;
in
{
  options.network.heartbeat = {
    enable = mkEnableOption "Starfleet OS Network Heartbeat";
    
    interval = mkOption {
      type = types.int;
      default = 30;
      description = "Heartbeat interval in seconds";
    };
    
    targets = mkOption {
      type = types.listOf types.str;
      default = [ "uss-enterprise-bridge" "borg-drone-alpha" "borg-drone-beta" ];
      description = "Heartbeat target nodes";
    };
    
    mqttBroker = mkOption {
      type = types.str;
      default = "borg-drone-alpha";
      description = "MQTT broker for heartbeat messages";
    };
    
    mqttPort = mkOption {
      type = types.int;
      default = 1883;
      description = "MQTT broker port";
    };
    
    mqttTopic = mkOption {
      type = types.str;
      default = "starfleet/heartbeat";
      description = "MQTT topic for heartbeat messages";
    };
  };

  config = mkIf cfg.enable {
    # MQTT client for heartbeat
    services.mosquitto = {
      enable = true;
      
      listeners = [
        {
          port = cfg.mqttPort;
          users = {
            heartbeat = {
              acl = [ "pattern readwrite ${cfg.mqttTopic}/#" ];
              password = "heartbeat-password";  # Should be replaced with proper secret management
            };
          };
        }
      ];
    };
    
    # Heartbeat service
    systemd.services.heartbeat-sender = {
      description = "Starfleet OS Heartbeat Sender";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "heartbeat-sender" ''
          #!/bin/bash
          
          INTERVAL=${toString cfg.interval}
          MQTT_BROKER="${cfg.mqttBroker}"
          MQTT_PORT=${toString cfg.mqttPort}
          MQTT_TOPIC="${cfg.mqttTopic}"
          HOSTNAME=$(hostname)
          
          echo "Starting Starfleet OS Heartbeat Sender"
          echo "Interval: $INTERVAL seconds"
          echo "MQTT Broker: $MQTT_BROKER:$MQTT_PORT"
          echo "MQTT Topic: $MQTT_TOPIC"
          
          while true; do
            # Get system info
            UPTIME=$(uptime -p)
            LOAD=$(uptime | awk '{print $(NF-2)" "$(NF-1)" "$(NF)}' | tr -d ',')
            MEM=$(free -m | awk '/Mem:/ {printf "%.1f%%", $3/$2*100}')
            DISK=$(df -h / | awk 'NR==2 {print $5}')
            
            # Create heartbeat message
            MESSAGE="{&quot;node&quot;:&quot;$HOSTNAME&quot;,&quot;timestamp&quot;:&quot;$(date -Iseconds)&quot;,&quot;uptime&quot;:&quot;$UPTIME&quot;,&quot;load&quot;:&quot;$LOAD&quot;,&quot;memory&quot;:&quot;$MEM&quot;,&quot;disk&quot;:&quot;$DISK&quot;}"
            
            # Send heartbeat
            ${pkgs.mosquitto}/bin/mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
              -t "$MQTT_TOPIC/$HOSTNAME" -m "$MESSAGE" \
              -u heartbeat -P heartbeat-password \
              -r
            
            # Wait for next interval
            sleep $INTERVAL
          done
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Heartbeat monitor service
    systemd.services.heartbeat-monitor = {
      description = "Starfleet OS Heartbeat Monitor";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "heartbeat-monitor" ''
          #!/bin/bash
          
          MQTT_BROKER="${cfg.mqttBroker}"
          MQTT_PORT=${toString cfg.mqttPort}
          MQTT_TOPIC="${cfg.mqttTopic}"
          TARGETS="${concatStringsSep " " cfg.targets}"
          MAX_AGE=$((${toString cfg.interval} * 3))
          
          echo "Starting Starfleet OS Heartbeat Monitor"
          echo "MQTT Broker: $MQTT_BROKER:$MQTT_PORT"
          echo "MQTT Topic: $MQTT_TOPIC"
          echo "Targets: $TARGETS"
          echo "Max age: $MAX_AGE seconds"
          
          # Create temporary directory for heartbeat data
          TEMP_DIR=$(mktemp -d)
          
          # Cleanup on exit
          trap "rm -rf $TEMP_DIR" EXIT
          
          # Subscribe to heartbeat messages
          ${pkgs.mosquitto}/bin/mosquitto_sub -h "$MQTT_BROKER" -p "$MQTT_PORT" \
            -t "$MQTT_TOPIC/#" \
            -u heartbeat -P heartbeat-password \
            --verbose | while read -r line; do
            
            # Extract node name from topic
            TOPIC=$(echo "$line" | awk '{print $1}')
            NODE=$(echo "$TOPIC" | cut -d'/' -f3)
            
            # Extract message
            MESSAGE=$(echo "$line" | cut -d' ' -f2-)
            
            # Save heartbeat data
            echo "$MESSAGE" > "$TEMP_DIR/$NODE"
            echo "Received heartbeat from $NODE"
            
            # Check all targets
            for target in $TARGETS; do
              if [ -f "$TEMP_DIR/$target" ]; then
                # Get timestamp from heartbeat
                TIMESTAMP=$(jq -r '.timestamp' "$TEMP_DIR/$target")
                TIMESTAMP_EPOCH=$(date -d "$TIMESTAMP" +%s)
                NOW_EPOCH=$(date +%s)
                AGE=$((NOW_EPOCH - TIMESTAMP_EPOCH))
                
                if [ $AGE -gt $MAX_AGE ]; then
                  echo "WARNING: Heartbeat from $target is too old ($AGE seconds)"
                  # Send alert (implement your preferred alert mechanism)
                  ${pkgs.libnotify}/bin/notify-send "Starfleet Alert" "Node $target heartbeat is too old!"
                fi
              else
                echo "WARNING: No heartbeat received from $target"
                # Send alert (implement your preferred alert mechanism)
                ${pkgs.libnotify}/bin/notify-send "Starfleet Alert" "No heartbeat from $target!"
              fi
            done
          done
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Heartbeat tools
    environment.systemPackages = with pkgs; [
      mosquitto
      jq
      
      # Helper scripts
      (writeScriptBin "heartbeat-status" ''
        #!/bin/bash
        echo "Starfleet OS Heartbeat Status"
        echo "============================"
        
        echo "Heartbeat sender:"
        systemctl status heartbeat-sender
        
        echo ""
        echo "Heartbeat monitor:"
        systemctl status heartbeat-monitor
        
        echo ""
        echo "Node status:"
        for target in ${concatStringsSep " " cfg.targets}; do
          echo -n "$target: "
          ${pkgs.mosquitto}/bin/mosquitto_sub -h "${cfg.mqttBroker}" -p ${toString cfg.mqttPort} \
            -t "${cfg.mqttTopic}/$target" \
            -u heartbeat -P heartbeat-password \
            -C 1 -W 1 | jq -r '"Last seen: \(.timestamp), Uptime: \(.uptime), Load: \(.load), Memory: \(.memory), Disk: \(.disk)"' || echo "OFFLINE"
        done
      '')
      
      (writeScriptBin "heartbeat-send" ''
        #!/bin/bash
        echo "Sending manual heartbeat..."
        
        HOSTNAME=$(hostname)
        UPTIME=$(uptime -p)
        LOAD=$(uptime | awk '{print $(NF-2)" "$(NF-1)" "$(NF)}' | tr -d ',')
        MEM=$(free -m | awk '/Mem:/ {printf "%.1f%%", $3/$2*100}')
        DISK=$(df -h / | awk 'NR==2 {print $5}')
        
        # Create heartbeat message
        MESSAGE="{&quot;node&quot;:&quot;$HOSTNAME&quot;,&quot;timestamp&quot;:&quot;$(date -Iseconds)&quot;,&quot;uptime&quot;:&quot;$UPTIME&quot;,&quot;load&quot;:&quot;$LOAD&quot;,&quot;memory&quot;:&quot;$MEM&quot;,&quot;disk&quot;:&quot;$DISK&quot;}"
        
        # Send heartbeat
        ${pkgs.mosquitto}/bin/mosquitto_pub -h "${cfg.mqttBroker}" -p ${toString cfg.mqttPort} \
          -t "${cfg.mqttTopic}/$HOSTNAME" -m "$MESSAGE" \
          -u heartbeat -P heartbeat-password \
          -r
        
        echo "Heartbeat sent"
      '')
    ];
  };
}