{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.backup-repo;
in
{
  options.services.backup-repo = {
    enable = mkEnableOption "Starfleet OS Backup Repository";
    
    storagePath = mkOption {
      type = types.str;
      default = "/var/lib/backups";
      description = "Path to store backups";
    };
    
    retentionDays = mkOption {
      type = types.int;
      default = 30;
      description = "Backup retention period in days";
    };
    
    scheduleDaily = mkOption {
      type = types.bool;
      default = true;
      description = "Enable daily backups";
    };
    
    scheduleWeekly = mkOption {
      type = types.bool;
      default = true;
      description = "Enable weekly backups";
    };
    
    scheduleMonthly = mkOption {
      type = types.bool;
      default = true;
      description = "Enable monthly backups";
    };
    
    encryption = mkOption {
      type = types.bool;
      default = true;
      description = "Enable backup encryption";
    };
  };

  config = mkIf cfg.enable {
    # Create backup directory
    systemd.tmpfiles.rules = [
      "d ${cfg.storagePath} 0750 root root -"
      "d ${cfg.storagePath}/daily 0750 root root -"
      "d ${cfg.storagePath}/weekly 0750 root root -"
      "d ${cfg.storagePath}/monthly 0750 root root -"
      "d ${cfg.storagePath}/keys 0700 root root -"
    ];
    
    # BorgBackup for efficient backups
    services.borgbackup.jobs = {
      # Daily backup
      daily = mkIf cfg.scheduleDaily {
        paths = [
          "/etc"
          "/home"
          "/root"
          "/var/lib/starfleet"
        ];
        exclude = [
          "*.tmp"
          "*/cache/*"
          "*/tmp/*"
        ];
        repo = "${cfg.storagePath}/daily";
        encryption = if cfg.encryption then {
          mode = "repokey";
          passCommand = "cat ${cfg.storagePath}/keys/daily.key";
        } else null;
        compression = "auto,lzma";
        startAt = "daily";
        prune.keep = {
          daily = 7;
          weekly = 4;
          monthly = 0;
        };
        extraCreateArgs = [
          "--stats"
          "--checkpoint-interval" "300"
        ];
        extraPruneArgs = [
          "--stats"
        ];
      };
      
      # Weekly backup
      weekly = mkIf cfg.scheduleWeekly {
        paths = [
          "/etc"
          "/home"
          "/root"
          "/var/lib"
        ];
        exclude = [
          "*.tmp"
          "*/cache/*"
          "*/tmp/*"
        ];
        repo = "${cfg.storagePath}/weekly";
        encryption = if cfg.encryption then {
          mode = "repokey";
          passCommand = "cat ${cfg.storagePath}/keys/weekly.key";
        } else null;
        compression = "auto,lzma";
        startAt = "weekly";
        prune.keep = {
          daily = 0;
          weekly = 4;
          monthly = 6;
        };
        extraCreateArgs = [
          "--stats"
          "--checkpoint-interval" "300"
        ];
        extraPruneArgs = [
          "--stats"
        ];
      };
      
      # Monthly backup
      monthly = mkIf cfg.scheduleMonthly {
        paths = [
          "/"
        ];
        exclude = [
          "/dev/*"
          "/proc/*"
          "/sys/*"
          "/tmp/*"
          "/run/*"
          "/mnt/*"
          "/media/*"
          "/lost+found"
          "*.tmp"
          "*/cache/*"
          "*/tmp/*"
        ];
        repo = "${cfg.storagePath}/monthly";
        encryption = if cfg.encryption then {
          mode = "repokey";
          passCommand = "cat ${cfg.storagePath}/keys/monthly.key";
        } else null;
        compression = "auto,lzma";
        startAt = "monthly";
        prune.keep = {
          daily = 0;
          weekly = 0;
          monthly = 12;
          yearly = 3;
        };
        extraCreateArgs = [
          "--stats"
          "--checkpoint-interval" "300"
        ];
        extraPruneArgs = [
          "--stats"
        ];
      };
    };
    
    # Restic for alternative backup method
    services.restic.backups = {
      # System backup
      system = {
        paths = [
          "/etc"
          "/home"
          "/root"
          "/var/lib/starfleet"
        ];
        exclude = [
          "*.tmp"
          "*/cache/*"
          "*/tmp/*"
        ];
        repository = "local:${cfg.storagePath}/restic";
        passwordFile = "${cfg.storagePath}/keys/restic.key";
        initialize = true;
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
        pruneOpts = [
          "--keep-daily" "7"
          "--keep-weekly" "4"
          "--keep-monthly" "6"
        ];
      };
    };
    
    # Backup key generation
    systemd.services.backup-key-generation = {
      description = "Generate backup encryption keys";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      before = [ "borgbackup-job-daily.service" "borgbackup-job-weekly.service" "borgbackup-job-monthly.service" "restic-backups-system.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      
      script = ''
        # Generate keys if they don't exist
        if [ ! -f ${cfg.storagePath}/keys/daily.key ]; then
          ${pkgs.openssl}/bin/openssl rand -base64 32 > ${cfg.storagePath}/keys/daily.key
          chmod 600 ${cfg.storagePath}/keys/daily.key
        fi
        
        if [ ! -f ${cfg.storagePath}/keys/weekly.key ]; then
          ${pkgs.openssl}/bin/openssl rand -base64 32 > ${cfg.storagePath}/keys/weekly.key
          chmod 600 ${cfg.storagePath}/keys/weekly.key
        fi
        
        if [ ! -f ${cfg.storagePath}/keys/monthly.key ]; then
          ${pkgs.openssl}/bin/openssl rand -base64 32 > ${cfg.storagePath}/keys/monthly.key
          chmod 600 ${cfg.storagePath}/keys/monthly.key
        fi
        
        if [ ! -f ${cfg.storagePath}/keys/restic.key ]; then
          ${pkgs.openssl}/bin/openssl rand -base64 32 > ${cfg.storagePath}/keys/restic.key
          chmod 600 ${cfg.storagePath}/keys/restic.key
        fi
      '';
    };
    
    # Backup cleanup service
    systemd.services.backup-cleanup = {
      description = "Clean up old backups";
      startAt = "weekly";
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "backup-cleanup" ''
          #!/bin/bash
          
          echo "Cleaning up old backups..."
          
          # Find and remove old backup files
          find ${cfg.storagePath}/daily -type f -mtime +${toString cfg.retentionDays} -delete
          find ${cfg.storagePath}/weekly -type f -mtime +${toString (cfg.retentionDays * 7)} -delete
          find ${cfg.storagePath}/monthly -type f -mtime +${toString (cfg.retentionDays * 30)} -delete
          
          echo "Backup cleanup complete."
        ''}";
      };
    };
    
    # Backup tools
    environment.systemPackages = with pkgs; [
      borgbackup
      restic
      rclone
      rsync
      
      # Helper scripts
      (writeScriptBin "backup-status" ''
        #!/bin/bash
        echo "Starfleet OS Backup Repository Status"
        echo "===================================="
        
        echo "Storage location: ${cfg.storagePath}"
        echo "Storage usage:"
        du -sh ${cfg.storagePath}/*
        
        echo ""
        echo "BorgBackup status:"
        systemctl status borgbackup-job-daily
        systemctl status borgbackup-job-weekly
        systemctl status borgbackup-job-monthly
        
        echo ""
        echo "Restic status:"
        systemctl status restic-backups-system
        
        echo ""
        echo "Recent backup logs:"
        journalctl -u borgbackup-job-daily -u borgbackup-job-weekly -u borgbackup-job-monthly -u restic-backups-system --no-pager | tail -n 20
      '')
      
      (writeScriptBin "backup-now" ''
        #!/bin/bash
        if [ $# -eq 0 ]; then
          echo "Usage: backup-now [daily|weekly|monthly|system]"
          exit 1
        fi
        
        TYPE=$1
        
        case "$TYPE" in
          "daily")
            echo "Starting daily backup..."
            systemctl start borgbackup-job-daily
            ;;
          "weekly")
            echo "Starting weekly backup..."
            systemctl start borgbackup-job-weekly
            ;;
          "monthly")
            echo "Starting monthly backup..."
            systemctl start borgbackup-job-monthly
            ;;
          "system")
            echo "Starting system backup..."
            systemctl start restic-backups-system
            ;;
          *)
            echo "Invalid backup type: $TYPE"
            echo "Valid types: daily, weekly, monthly, system"
            exit 1
            ;;
        esac
        
        echo "Backup started. Check status with 'backup-status'"
      '')
      
      (writeScriptBin "backup-restore" ''
        #!/bin/bash
        if [ $# -lt 3 ]; then
          echo "Usage: backup-restore [daily|weekly|monthly|system] <archive> <destination>"
          exit 1
        fi
        
        TYPE=$1
        ARCHIVE=$2
        DEST=$3
        
        case "$TYPE" in
          "daily")
            echo "Restoring from daily backup..."
            borg extract ${cfg.storagePath}/daily::$ARCHIVE $DEST
            ;;
          "weekly")
            echo "Restoring from weekly backup..."
            borg extract ${cfg.storagePath}/weekly::$ARCHIVE $DEST
            ;;
          "monthly")
            echo "Restoring from monthly backup..."
            borg extract ${cfg.storagePath}/monthly::$ARCHIVE $DEST
            ;;
          "system")
            echo "Restoring from system backup..."
            mkdir -p $DEST
            restic -r local:${cfg.storagePath}/restic restore $ARCHIVE --target $DEST
            ;;
          *)
            echo "Invalid backup type: $TYPE"
            echo "Valid types: daily, weekly, monthly, system"
            exit 1
            ;;
        esac
        
        echo "Restore complete to $DEST"
      '')
    ];
  };
}