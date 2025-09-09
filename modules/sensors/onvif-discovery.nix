{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.onvif-discovery;
in
{
  options.services.onvif-discovery = {
    enable = mkEnableOption "Starfleet OS ONVIF/RTSP Discovery";
    
    scanInterval = mkOption {
      type = types.int;
      default = 300;
      description = "Scan interval in seconds";
    };
    
    networkRange = mkOption {
      type = types.str;
      default = "192.168.1.0/24";
      description = "Network range to scan";
    };
    
    outputPath = mkOption {
      type = types.str;
      default = "/var/lib/onvif-discovery";
      description = "Path to store discovery results";
    };
    
    enableProxy = mkOption {
      type = types.bool;
      default = true;
      description = "Enable RTSP proxy for discovered cameras";
    };
    
    proxyPort = mkOption {
      type = types.int;
      default = 8554;
      description = "RTSP proxy port";
    };
  };

  config = mkIf cfg.enable {
    # Create output directory
    systemd.tmpfiles.rules = [
      "d ${cfg.outputPath} 0750 onvif onvif -"
      "d ${cfg.outputPath}/cameras 0750 onvif onvif -"
      "d ${cfg.outputPath}/snapshots 0750 onvif onvif -"
      "d ${cfg.outputPath}/streams 0750 onvif onvif -"
    ];
    
    # ONVIF discovery service
    systemd.services.onvif-discovery = {
      description = "Starfleet OS ONVIF Discovery Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "onvif";
        Group = "onvif";
        ExecStart = "${pkgs.writeShellScript "onvif-discovery" ''
          #!/bin/bash
          
          SCAN_INTERVAL=${toString cfg.scanInterval}
          NETWORK_RANGE="${cfg.networkRange}"
          OUTPUT_PATH="${cfg.outputPath}"
          
          echo "Starting Starfleet OS ONVIF Discovery Service"
          echo "Scan interval: $SCAN_INTERVAL seconds"
          echo "Network range: $NETWORK_RANGE"
          echo "Output path: $OUTPUT_PATH"
          
          # Function to discover ONVIF cameras
          discover_onvif() {
            echo "$(date): Scanning for ONVIF cameras..."
            
            # Use onvif-tool to discover cameras
            ${pkgs.onvif-tool}/bin/onvif-discover -t 5 | jq -r '.[]' > "$OUTPUT_PATH/cameras/onvif.json"
            
            # Count discovered cameras
            COUNT=$(jq length "$OUTPUT_PATH/cameras/onvif.json")
            echo "$(date): Discovered $COUNT ONVIF cameras"
          }
          
          # Function to discover RTSP streams
          discover_rtsp() {
            echo "$(date): Scanning for RTSP streams..."
            
            # Use nmap to scan for RTSP ports
            ${pkgs.nmap}/bin/nmap -p 554 --open $NETWORK_RANGE -oG - | grep "554/open" | awk '{print $2}' > "$OUTPUT_PATH/cameras/rtsp_hosts.txt"
            
            # Count discovered hosts
            COUNT=$(wc -l < "$OUTPUT_PATH/cameras/rtsp_hosts.txt")
            echo "$(date): Discovered $COUNT hosts with RTSP port open"
            
            # Try common RTSP URLs for each host
            > "$OUTPUT_PATH/cameras/rtsp_urls.txt"
            while read -r host; do
              for path in "/live/ch00_0" "/live/ch01_0" "/cam/realmonitor?channel=1&subtype=0" "/h264Preview_01_main" "/media/video1" "/stream1" "/11" "/live.sdp"; do
                echo "rtsp://$host$path" >> "$OUTPUT_PATH/cameras/rtsp_urls.txt"
              done
            done < "$OUTPUT_PATH/cameras/rtsp_hosts.txt"
          }
          
          # Function to take snapshots from discovered streams
          take_snapshots() {
            echo "$(date): Taking snapshots from discovered streams..."
            
            # Create snapshots directory
            mkdir -p "$OUTPUT_PATH/snapshots"
            
            # Take snapshots from ONVIF cameras
            jq -r '.[] | .ip + ":" + (.port|tostring) + .path' "$OUTPUT_PATH/cameras/onvif.json" | while read -r url; do
              name=$(echo "$url" | sed 's/[:/.]/_/g')
              ${pkgs.ffmpeg}/bin/ffmpeg -y -i "rtsp://$url" -frames:v 1 "$OUTPUT_PATH/snapshots/$name.jpg" || true
            done
            
            # Take snapshots from RTSP URLs
            while read -r url; do
              name=$(echo "$url" | sed 's/[:/.]/_/g')
              ${pkgs.ffmpeg}/bin/ffmpeg -y -i "$url" -frames:v 1 "$OUTPUT_PATH/snapshots/$name.jpg" || true
            done < "$OUTPUT_PATH/cameras/rtsp_urls.txt"
          }
          
          # Function to generate camera list
          generate_camera_list() {
            echo "$(date): Generating camera list..."
            
            # Create camera list
            > "$OUTPUT_PATH/cameras/camera_list.json"
            
            # Add ONVIF cameras
            jq -r '.[] | {id: (.ip + ":" + (.port|tostring) + .path), name: .ip, url: ("rtsp://" + .ip + ":" + (.port|tostring) + .path), type: "onvif"}' "$OUTPUT_PATH/cameras/onvif.json" | jq -s '.' > "$OUTPUT_PATH/cameras/camera_list.json"
            
            # Add RTSP URLs with valid snapshots
            while read -r url; do
              name=$(echo "$url" | sed 's/[:/.]/_/g')
              if [ -f "$OUTPUT_PATH/snapshots/$name.jpg" ]; then
                id=$(echo "$url" | sed 's/rtsp:\/\///')
                name=$(echo "$url" | cut -d'/' -f3)
                echo "{&quot;id&quot;:&quot;$id&quot;,&quot;name&quot;:&quot;$name&quot;,&quot;url&quot;:&quot;$url&quot;,&quot;type&quot;:&quot;rtsp&quot;}" | jq '.' >> "$OUTPUT_PATH/cameras/camera_list_rtsp.json"
              fi
            done < "$OUTPUT_PATH/cameras/rtsp_urls.txt"
            
            # Merge camera lists
            if [ -f "$OUTPUT_PATH/cameras/camera_list_rtsp.json" ]; then
              jq -s '.[0] + .[1]' "$OUTPUT_PATH/cameras/camera_list.json" "$OUTPUT_PATH/cameras/camera_list_rtsp.json" > "$OUTPUT_PATH/cameras/all_cameras.json"
              mv "$OUTPUT_PATH/cameras/all_cameras.json" "$OUTPUT_PATH/cameras/camera_list.json"
            fi
            
            # Count cameras
            COUNT=$(jq length "$OUTPUT_PATH/cameras/camera_list.json")
            echo "$(date): Generated list with $COUNT cameras"
          }
          
          # Main loop
          while true; do
            discover_onvif
            discover_rtsp
            take_snapshots
            generate_camera_list
            
            echo "$(date): Waiting $SCAN_INTERVAL seconds for next scan..."
            sleep $SCAN_INTERVAL
          done
        ''}";
        Restart = "always";
        RestartSec = 10;
        WorkingDirectory = cfg.outputPath;
      };
    };
    
    # RTSP proxy service
    systemd.services.rtsp-proxy = mkIf cfg.enableProxy {
      description = "Starfleet OS RTSP Proxy";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "onvif-discovery.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "onvif";
        Group = "onvif";
        ExecStart = "${pkgs.writeShellScript "rtsp-proxy" ''
          #!/bin/bash
          
          OUTPUT_PATH="${cfg.outputPath}"
          PROXY_PORT=${toString cfg.proxyPort}
          
          echo "Starting Starfleet OS RTSP Proxy"
          echo "Proxy port: $PROXY_PORT"
          
          # Wait for camera list
          while [ ! -f "$OUTPUT_PATH/cameras/camera_list.json" ]; do
            echo "Waiting for camera list..."
            sleep 10
          done
          
          # Generate rtsp-simple-server config
          cat > "$OUTPUT_PATH/rtsp-simple-server.yml" << EOF
          rtsp:
            protocols: [tcp, udp]
            port: $PROXY_PORT
          
          paths:
          EOF
          
          # Add paths for each camera
          jq -r '.[] | "  " + (.id | gsub("[:/]"; "_")) + ":\\n    source: " + .url' "$OUTPUT_PATH/cameras/camera_list.json" >> "$OUTPUT_PATH/rtsp-simple-server.yml"
          
          # Start rtsp-simple-server
          ${pkgs.rtsp-simple-server}/bin/rtsp-simple-server "$OUTPUT_PATH/rtsp-simple-server.yml"
        ''}";
        Restart = "always";
        RestartSec = 10;
        WorkingDirectory = cfg.outputPath;
      };
    };
    
    # ONVIF user
    users.users.onvif = {
      isSystemUser = true;
      group = "onvif";
      description = "ONVIF service user";
      home = cfg.outputPath;
      createHome = true;
    };
    
    users.groups.onvif = {};
    
    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts = mkIf cfg.enableProxy [
        cfg.proxyPort  # RTSP proxy
      ];
    };
    
    # ONVIF tools
    environment.systemPackages = with pkgs; [
      onvif-tool
      ffmpeg
      rtsp-simple-server
      jq
      
      # Helper scripts
      (writeScriptBin "onvif-status" ''
        #!/bin/bash
        echo "Starfleet OS ONVIF/RTSP Discovery Status"
        echo "======================================"
        
        echo "Discovery service:"
        systemctl status onvif-discovery
        
        echo ""
        echo "RTSP proxy:"
        if ${toString cfg.enableProxy}; then
          systemctl status rtsp-proxy
        else
          echo "RTSP proxy disabled"
        fi
        
        echo ""
        echo "Discovered cameras:"
        if [ -f "${cfg.outputPath}/cameras/camera_list.json" ]; then
          jq -r '.[] | "- " + .name + " (" + .type + "): " + .url' "${cfg.outputPath}/cameras/camera_list.json"
        else
          echo "No cameras discovered yet"
        fi
        
        echo ""
        echo "Snapshots:"
        ls -la "${cfg.outputPath}/snapshots" | grep -v "^total" | grep -v "^d"
      '')
      
      (writeScriptBin "onvif-scan" ''
        #!/bin/bash
        echo "Starting manual ONVIF/RTSP scan..."
        
        systemctl restart onvif-discovery
        
        echo "Scan initiated. Check status with 'onvif-status'"
      '')
      
      (writeScriptBin "onvif-view" ''
        #!/bin/bash
        if [ $# -lt 1 ]; then
          echo "Usage: onvif-view <camera_id>"
          echo "Available cameras:"
          jq -r '.[] | .id + " (" + .name + ")"' "${cfg.outputPath}/cameras/camera_list.json"
          exit 1
        fi
        
        CAMERA_ID=$1
        
        # Find camera URL
        URL=$(jq -r ".[] | select(.id == &quot;$CAMERA_ID&quot;) | .url" "${cfg.outputPath}/cameras/camera_list.json")
        
        if [ -z "$URL" ]; then
          echo "Camera not found: $CAMERA_ID"
          exit 1
        fi
        
        echo "Viewing camera: $CAMERA_ID"
        echo "URL: $URL"
        
        # Open camera stream
        ${ffmpeg}/bin/ffplay -i "$URL"
      '')
    ];
  };
}