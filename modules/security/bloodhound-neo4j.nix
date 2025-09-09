{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.bloodhound-neo4j;
in
{
  options.services.bloodhound-neo4j = {
    enable = mkEnableOption "Starfleet OS BloodHound and Neo4j";
    
    neo4jPort = mkOption {
      type = types.int;
      default = 7474;
      description = "Neo4j HTTP port";
    };
    
    neo4jBoltPort = mkOption {
      type = types.int;
      default = 7687;
      description = "Neo4j Bolt port";
    };
    
    bloodhoundPort = mkOption {
      type = types.int;
      default = 8080;
      description = "BloodHound server port";
    };
    
    dataPath = mkOption {
      type = types.str;
      default = "/var/lib/bloodhound";
      description = "Path to store BloodHound data";
    };
  };

  config = mkIf cfg.enable {
    # Create data directory
    systemd.tmpfiles.rules = [
      "d ${cfg.dataPath} 0750 bloodhound bloodhound -"
      "d ${cfg.dataPath}/neo4j 0750 bloodhound bloodhound -"
      "d ${cfg.dataPath}/uploads 0750 bloodhound bloodhound -"
    ];
    
    # Neo4j database for BloodHound
    services.neo4j = {
      enable = true;
      package = pkgs.neo4j;
      
      bolt.enable = true;
      bolt.listenAddress = "0.0.0.0:${toString cfg.neo4jBoltPort}";
      
      http.enable = true;
      http.listenAddress = "0.0.0.0:${toString cfg.neo4jPort}";
      
      directories.data = "${cfg.dataPath}/neo4j";
      
      extraServerConfig = ''
        dbms.security.auth_enabled=true
        dbms.security.procedures.unrestricted=apoc.*
        dbms.memory.heap.initial_size=1G
        dbms.memory.heap.max_size=2G
        dbms.memory.pagecache.size=1G
      '';
    };
    
    # BloodHound service
    systemd.services.bloodhound = {
      description = "BloodHound Active Directory reconnaissance";
      wantedBy = [ "multi-user.target" ];
      after = [ "neo4j.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "bloodhound";
        Group = "bloodhound";
        ExecStart = "${pkgs.bloodhound}/bin/bloodhound --no-sandbox";
        Restart = "always";
        WorkingDirectory = cfg.dataPath;
      };
      
      environment = {
        NEO4J_URI = "bolt://localhost:${toString cfg.neo4jBoltPort}";
        NEO4J_USER = "neo4j";
        NEO4J_PASSWORD = "bloodhound";
        BLOODHOUND_PORT = toString cfg.bloodhoundPort;
      };
    };
    
    # SharpHound collector service
    systemd.services.sharphound-collector = {
      description = "SharpHound data collector service";
      
      serviceConfig = {
        Type = "oneshot";
        User = "bloodhound";
        Group = "bloodhound";
        ExecStart = "${pkgs.writeShellScript "sharphound-collector" ''
          #!/bin/bash
          
          # Download latest SharpHound collector
          ${pkgs.curl}/bin/curl -L -o ${cfg.dataPath}/SharpHound.ps1 \
            https://raw.githubusercontent.com/BloodHoundAD/BloodHound/master/Collectors/SharpHound.ps1
          
          echo "SharpHound collector downloaded to ${cfg.dataPath}/SharpHound.ps1"
          echo "Run this script on a domain-joined Windows machine to collect data"
        ''}";
      };
    };
    
    # BloodHound user
    users.users.bloodhound = {
      isSystemUser = true;
      group = "bloodhound";
      description = "BloodHound service user";
      home = cfg.dataPath;
      createHome = true;
    };
    
    users.groups.bloodhound = {};
    
    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts = [
        cfg.neo4jPort
        cfg.neo4jBoltPort
        cfg.bloodhoundPort
      ];
    };
    
    # BloodHound tools
    environment.systemPackages = with pkgs; [
      bloodhound
      neo4j
      cypher-shell
      
      # Helper scripts
      (writeScriptBin "bloodhound-status" ''
        #!/bin/bash
        echo "Starfleet OS BloodHound Status"
        echo "============================="
        
        echo "Neo4j status:"
        systemctl status neo4j
        
        echo ""
        echo "BloodHound status:"
        systemctl status bloodhound
        
        echo ""
        echo "Neo4j database:"
        cypher-shell -u neo4j -p bloodhound "MATCH (n) RETURN count(n) as NodeCount"
        
        echo ""
        echo "Access URLs:"
        echo "Neo4j Browser: http://localhost:${toString cfg.neo4jPort}"
        echo "BloodHound: http://localhost:${toString cfg.bloodhoundPort}"
      '')
      
      (writeScriptBin "bloodhound-import" ''
        #!/bin/bash
        if [ $# -lt 1 ]; then
          echo "Usage: bloodhound-import <zip_file>"
          exit 1
        fi
        
        ZIP_FILE=$1
        
        if [ ! -f "$ZIP_FILE" ]; then
          echo "File not found: $ZIP_FILE"
          exit 1
        fi
        
        echo "Importing BloodHound data from $ZIP_FILE"
        
        # Extract ZIP file
        TEMP_DIR=$(mktemp -d)
        unzip -q "$ZIP_FILE" -d "$TEMP_DIR"
        
        # Import JSON files
        for json_file in "$TEMP_DIR"/*.json; do
          echo "Importing $json_file"
          ${pkgs.bloodhound-import}/bin/bloodhound-import \
            -u neo4j -p bloodhound \
            -f "$json_file"
        done
        
        # Clean up
        rm -rf "$TEMP_DIR"
        
        echo "Import complete"
      '')
      
      (writeScriptBin "bloodhound-reset" ''
        #!/bin/bash
        echo "This will reset the BloodHound database."
        echo "All data will be lost!"
        echo "Press Ctrl+C to cancel or Enter to continue..."
        read
        
        echo "Resetting BloodHound database..."
        
        # Stop services
        systemctl stop bloodhound
        systemctl stop neo4j
        
        # Reset database
        rm -rf ${cfg.dataPath}/neo4j/data/databases/*
        rm -rf ${cfg.dataPath}/neo4j/data/transactions/*
        
        # Start services
        systemctl start neo4j
        systemctl start bloodhound
        
        echo "BloodHound database reset complete"
      '')
    ];
  };
}