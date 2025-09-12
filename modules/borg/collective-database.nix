{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg-collective-db;
in
{
  options.services.borg-collective-db = {
    enable = mkEnableOption "Borg Collective Database";
    
    role = mkOption {
      type = types.enum [ "primary" "replica" "edge" ];
      default = "replica";
      description = "Database node role";
    };
    
    storageSize = mkOption {
      type = types.str;
      default = "10G";
      description = "Storage size for database";
    };
    
    replicationFactor = mkOption {
      type = types.int;
      default = 3;
      description = "Replication factor for data";
    };
    
    retentionPeriod = mkOption {
      type = types.str;
      default = "30d";
      description = "Data retention period";
    };
    
    backupInterval = mkOption {
      type = types.str;
      default = "hourly";
      description = "Backup interval";
    };
    
    encryptionEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable database encryption";
    };
    
    autoHeal = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic healing of database";
    };
  };

  config = mkIf cfg.enable {
    # CockroachDB service
    services.cockroachdb = {
      enable = true;
      insecure = false;
      http = {
        port = 8080;
        address = "0.0.0.0";
      };
      listen = {
        port = 26257;
        address = "0.0.0.0";
      };
      locality = "role=${cfg.role}";
      join = [ "borg-drone-alpha:26257" "borg-drone-beta:26257" ];
      
      # Additional CockroachDB settings
      extraFlags = [
        "--cache=${toString (lib.toInt (builtins.substring 0 (builtins.stringLength cfg.storageSize - 1) cfg.storageSize) / 4)}G"
        "--max-sql-memory=${toString (lib.toInt (builtins.substring 0 (builtins.stringLength cfg.storageSize - 1) cfg.storageSize) / 4)}G"
        "--store=path=/var/lib/cockroach,size=${cfg.storageSize}"
        "--cluster-name=borg-collective"
      ] ++ (if cfg.encryptionEnabled then [ "--enterprise-encryption=path=/var/lib/cockroach,key=auto,old-key=auto" ] else []);
    };
    
    # Database initialization
    systemd.services.borg-db-init = {
      description = "Initialize Borg Collective Database";
      wantedBy = [ "multi-user.target" ];
      after = [ "cockroachdb.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-collective-db}/bin/init-db";
      };
      
      environment = {
        DB_ROLE = cfg.role;
        REPLICATION_FACTOR = toString cfg.replicationFactor;
        RETENTION_PERIOD = cfg.retentionPeriod;
      };
    };
    
    # Database backup service
    systemd.services.borg-db-backup = {
      description = "Backup Borg Collective Database";
      startAt = cfg.backupInterval;
      
      serviceConfig = {
        Type = "oneshot";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-collective-db}/bin/backup-db";
      };
      
      environment = {
        BACKUP_PATH = "/var/lib/cockroach/backups";
        ENCRYPTION_ENABLED = if cfg.encryptionEnabled then "true" else "false";
      };
    };
    
    # Database health check
    systemd.services.borg-db-health = {
      description = "Borg Collective Database Health Check";
      startAt = "*:0/15";
      
      serviceConfig = {
        Type = "oneshot";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-collective-db}/bin/health-check";
      };
      
      environment = {
        AUTO_HEAL = if cfg.autoHeal then "true" else "false";
      };
    };
    
    # Database metrics exporter
    services.prometheus.exporters.cockroachdb = {
      enable = true;
      port = 9090;
      openFirewall = true;
    };
    
    # Required packages
    environment.systemPackages = with pkgs; [
      cockroachdb
      postgresql
      borg-collective-db-tools
    ];
    
    # Storage configuration
    fileSystems."/var/lib/cockroach" = mkIf (cfg.role == "primary" || cfg.role == "replica") {
      device = "/dev/disk/by-label/BORG_DB";
      fsType = "ext4";
      options = [ "defaults" "noatime" ];
    };
    
    # Database management tools
    environment.systemPackages = with pkgs; [
      (writeScriptBin "borg-db-status" ''
        #!/bin/bash
        echo "Borg Collective Database Status"
        echo "==============================="
        echo "Role: ${cfg.role}"
        echo "Storage Size: ${cfg.storageSize}"
        echo "Replication Factor: ${toString cfg.replicationFactor}"
        echo "Retention Period: ${cfg.retentionPeriod}"
        echo "Encryption: ${if cfg.encryptionEnabled then "Enabled" else "Disabled"}"
        echo "Auto-Heal: ${if cfg.autoHeal then "Enabled" else "Disabled"}"
        echo ""
        
        echo "Database Status:"
        cockroach node status --insecure
        
        echo ""
        echo "Database Health:"
        cockroach node status --insecure | grep "is_available"
        
        echo ""
        echo "Recent Backups:"
        ls -la /var/lib/cockroach/backups
      '')
      
      (writeScriptBin "borg-db-query" ''
        #!/bin/bash
        if [ $# -lt 1 ]; then
          echo "Usage: borg-db-query <sql-query>"
          exit 1
        fi
        
        cockroach sql --insecure -e "$1"
      '')
    ];
    
    # Firewall configuration
    networking.firewall.allowedTCPPorts = [
      26257  # CockroachDB
      8080   # CockroachDB HTTP
      9090   # Prometheus exporter
    ];
  };
}