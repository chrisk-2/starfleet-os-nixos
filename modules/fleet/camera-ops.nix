{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.camera-ops;
in
{
  options.services.camera-ops = {
    enable = mkEnableOption "Starfleet OS Camera Operations";
    
    discoveryInterval = mkOption {
      type = types.int;
      default = 300;
      description = "Camera discovery interval in seconds";
    };
    
    recordingPath = mkOption {
      type = types.str;
      default = "/var/lib/camera-recordings";
      description = "Path to store camera recordings";
    };
    
    retentionDays = mkOption {
      type = types.int;
      default = 7;
      description = "Number of days to retain recordings";
    };
  };

  config = mkIf cfg.enable {
    # Create recording directory
    systemd.tmpfiles.rules = [
      "d ${cfg.recordingPath} 0750 starfleet starfleet -"
    ];
    
    # Camera discovery service
    systemd.services.camera-discovery = {
      description = "Starfleet OS Camera Discovery Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.writeShellScript "camera-discovery" ''
          #!/bin/bash
          
          DISCOVERY_INTERVAL=${toString cfg.discoveryInterval}
          CONFIG_FILE="/etc/starfleet/cameras.json"
          
          echo "Starting Starfleet OS Camera Discovery Service"
          echo "Discovery interval: $DISCOVERY_INTERVAL seconds"
          
          mkdir -p /etc/starfleet
          
          while true; do
            echo "[$(date)] Running camera discovery..."
            
            # Use onvif-tool to discover cameras
            ${pkgs.onvif-tool}/bin/onvif-discover -t 5 | jq -r '.[] | {ip: .ip, port: .port, path: .path}' > $CONFIG_FILE
            
            echo "[$(date)] Found $(jq length $CONFIG_FILE) cameras"
            
            sleep $DISCOVERY_INTERVAL
          done
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Camera recording service
    systemd.services.camera-recorder = {
      description = "Starfleet OS Camera Recording Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "camera-discovery.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.writeShellScript "camera-recorder" ''
          #!/bin/bash
          
          CONFIG_FILE="/etc/starfleet/cameras.json"
          RECORDING_PATH="${cfg.recordingPath}"
          
          echo "Starting Starfleet OS Camera Recording Service"
          echo "Recording path: $RECORDING_PATH"
          
          # Wait for camera discovery
          while [ ! -f $CONFIG_FILE ]; do
            echo "Waiting for camera discovery..."
            sleep 10
          done
          
          # Start recording from each camera
          for camera in $(jq -c '.[]' $CONFIG_FILE); do
            IP=$(echo $camera | jq -r '.ip')
            PORT=$(echo $camera | jq -r '.port')
            PATH=$(echo $camera | jq -r '.path')
            
            STREAM_URL="rtsp://$IP:$PORT$PATH"
            OUTPUT_DIR="$RECORDING_PATH/$IP"
            
            mkdir -p $OUTPUT_DIR
            
            echo "Starting recording from $STREAM_URL"
            
            # Start ffmpeg in background
            ${pkgs.ffmpeg}/bin/ffmpeg -i "$STREAM_URL" -c copy -f segment -segment_time 3600 -segment_format mp4 "$OUTPUT_DIR/recording-%Y%m%d-%H%M%S.mp4" &
          done
          
          # Keep the service running
          wait
        ''}";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Cleanup old recordings
    systemd.services.camera-cleanup = {
      description = "Starfleet OS Camera Recording Cleanup";
      startAt = "daily";
      
      serviceConfig = {
        Type = "oneshot";
        User = "starfleet";
        Group = "starfleet";
        ExecStart = "${pkgs.writeShellScript "camera-cleanup" ''
          #!/bin/bash
          
          RECORDING_PATH="${cfg.recordingPath}"
          RETENTION_DAYS=${toString cfg.retentionDays}
          
          echo "Cleaning up recordings older than $RETENTION_DAYS days"
          
          find $RECORDING_PATH -type f -name "*.mp4" -mtime +$RETENTION_DAYS -delete
          
          echo "Cleanup complete"
        ''}";
      };
    };
    
    # Camera operations tools
    environment.systemPackages = with pkgs; [
      ffmpeg
      v4l-utils
      onvif-tool
      vlc
      
      # Camera dashboard script
      (writeScriptBin "camera-dashboard" ''
        #!/bin/bash
        echo "Starfleet OS Camera Operations Dashboard"
        echo "======================================"
        
        if [ -f /etc/starfleet/cameras.json ]; then
          echo "Discovered cameras:"
          jq -r '.[] | "- \(.ip):\(.port)\(.path)"' /etc/starfleet/cameras.json
          
          echo ""
          echo "Recording status:"
          ps aux | grep ffmpeg | grep -v grep
          
          echo ""
          echo "Storage usage:"
          du -sh ${cfg.recordingPath}
        else
          echo "No cameras discovered yet"
        fi
      '')
    ];
  };
}