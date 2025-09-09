{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.system.ventoy-recovery;
in
{
  options.system.ventoy-recovery = {
    enable = mkEnableOption "Starfleet OS Ventoy Recovery Kit";
    
    recoveryPath = mkOption {
      type = types.str;
      default = "/var/lib/ventoy-recovery";
      description = "Path to store recovery files";
    };
    
    backupInterval = mkOption {
      type = types.str;
      default = "weekly";
      description = "Backup interval (daily, weekly, monthly)";
    };
    
    includeConfigs = mkOption {
      type = types.bool;
      default = true;
      description = "Include system configurations in recovery kit";
    };
    
    includeHomeDir = mkOption {
      type = types.bool;
      default = true;
      description = "Include home directories in recovery kit";
    };
    
    includeDatabase = mkOption {
      type = types.bool;
      default = true;
      description = "Include database dumps in recovery kit";
    };
  };

  config = mkIf cfg.enable {
    # Create recovery directory
    systemd.tmpfiles.rules = [
      "d ${cfg.recoveryPath} 0750 root root -"
      "d ${cfg.recoveryPath}/configs 0750 root root -"
      "d ${cfg.recoveryPath}/backups 0750 root root -"
      "d ${cfg.recoveryPath}/isos 0750 root root -"
      "d ${cfg.recoveryPath}/ventoy 0750 root root -"
    ];
    
    # Ventoy installation service
    systemd.services.ventoy-install = {
      description = "Install Ventoy for Starfleet OS Recovery";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      
      script = ''
        #!/bin/bash
        
        VENTOY_VERSION="1.0.96"
        VENTOY_PATH="${cfg.recoveryPath}/ventoy"
        
        # Check if Ventoy is already installed
        if [ -f "$VENTOY_PATH/ventoy-$VENTOY_VERSION-linux.tar.gz" ]; then
          echo "Ventoy $VENTOY_VERSION is already installed"
          exit 0
        fi
        
        echo "Installing Ventoy $VENTOY_VERSION"
        
        # Download Ventoy
        ${pkgs.curl}/bin/curl -L -o "$VENTOY_PATH/ventoy-$VENTOY_VERSION-linux.tar.gz" \
          "https://github.com/ventoy/Ventoy/releases/download/v$VENTOY_VERSION/ventoy-$VENTOY_VERSION-linux.tar.gz"
        
        # Extract Ventoy
        ${pkgs.gnutar}/bin/tar -xzf "$VENTOY_PATH/ventoy-$VENTOY_VERSION-linux.tar.gz" -C "$VENTOY_PATH"
        
        echo "Ventoy $VENTOY_VERSION installed successfully"
      '';
    };
    
    # Recovery backup service
    systemd.services.ventoy-recovery-backup = {
      description = "Starfleet OS Recovery Backup";
      startAt = cfg.backupInterval;
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "ventoy-recovery-backup" ''
          #!/bin/bash
          
          RECOVERY_PATH="${cfg.recoveryPath}"
          BACKUP_PATH="$RECOVERY_PATH/backups"
          CONFIG_PATH="$RECOVERY_PATH/configs"
          ISO_PATH="$RECOVERY_PATH/isos"
          
          echo "Starting Starfleet OS Recovery Backup"
          
          # Create timestamp
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)
          
          # Backup system configurations
          if ${toString cfg.includeConfigs}; then
            echo "Backing up system configurations..."
            
            # Create config directory
            mkdir -p "$CONFIG_PATH/$TIMESTAMP"
            
            # Backup NixOS configuration
            cp -r /etc/nixos "$CONFIG_PATH/$TIMESTAMP/"
            
            # Backup network configuration
            cp -r /etc/NetworkManager/system-connections "$CONFIG_PATH/$TIMESTAMP/"
            
            # Backup SSH keys
            cp -r /etc/ssh "$CONFIG_PATH/$TIMESTAMP/"
            
            # Backup Starfleet configuration
            cp -r /etc/starfleet "$CONFIG_PATH/$TIMESTAMP/"
            
            # Create tarball
            ${pkgs.gnutar}/bin/tar -czf "$BACKUP_PATH/configs-$TIMESTAMP.tar.gz" -C "$CONFIG_PATH" "$TIMESTAMP"
            
            # Remove temporary directory
            rm -rf "$CONFIG_PATH/$TIMESTAMP"
          fi
          
          # Backup home directories
          if ${toString cfg.includeHomeDir}; then
            echo "Backing up home directories..."
            
            # Create home backup
            ${pkgs.rsync}/bin/rsync -az --exclude="*/cache/*" --exclude="*/tmp/*" \
              /home/starfleet "$BACKUP_PATH/home-$TIMESTAMP.tar.gz"
          fi
          
          # Backup databases
          if ${toString cfg.includeDatabase}; then
            echo "Backing up databases..."
            
            # Check for PostgreSQL
            if systemctl is-active --quiet postgresql; then
              echo "Backing up PostgreSQL databases..."
              sudo -u postgres ${pkgs.postgresql}/bin/pg_dumpall > "$BACKUP_PATH/postgresql-$TIMESTAMP.sql"
            fi
            
            # Check for MySQL/MariaDB
            if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
              echo "Backing up MySQL/MariaDB databases..."
              ${pkgs.mariadb}/bin/mysqldump --all-databases > "$BACKUP_PATH/mysql-$TIMESTAMP.sql"
            fi
            
            # Check for Neo4j
            if systemctl is-active --quiet neo4j; then
              echo "Backing up Neo4j databases..."
              ${pkgs.neo4j}/bin/neo4j-admin backup --backup-dir "$BACKUP_PATH/neo4j-$TIMESTAMP"
            fi
          fi
          
          # Download latest NixOS minimal ISO
          echo "Downloading latest NixOS minimal ISO..."
          ${pkgs.curl}/bin/curl -L -o "$ISO_PATH/nixos-minimal-latest.iso" \
            "https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso"
          
          echo "Recovery backup completed successfully"
        ''}";
      };
    };
    
    # Recovery kit creation service
    systemd.services.ventoy-recovery-kit = {
      description = "Create Starfleet OS Ventoy Recovery Kit";
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "ventoy-recovery-kit" ''
          #!/bin/bash
          
          RECOVERY_PATH="${cfg.recoveryPath}"
          VENTOY_PATH="$RECOVERY_PATH/ventoy"
          ISO_PATH="$RECOVERY_PATH/isos"
          BACKUP_PATH="$RECOVERY_PATH/backups"
          
          echo "Creating Starfleet OS Ventoy Recovery Kit"
          
          # Check if USB drive is provided
          if [ $# -lt 1 ]; then
            echo "Usage: ventoy-recovery-kit <usb_device>"
            echo "Example: ventoy-recovery-kit /dev/sdb"
            exit 1
          fi
          
          USB_DEVICE=$1
          
          # Confirm USB device
          echo "WARNING: This will erase all data on $USB_DEVICE!"
          echo "Are you sure you want to continue? (y/n)"
          read -r confirm
          
          if [ "$confirm" != "y" ]; then
            echo "Aborted"
            exit 1
          fi
          
          # Install Ventoy to USB drive
          echo "Installing Ventoy to $USB_DEVICE..."
          cd "$VENTOY_PATH/ventoy-"*
          ./Ventoy2Disk.sh -i "$USB_DEVICE"
          
          # Wait for USB drive to be remounted
          echo "Waiting for USB drive to be remounted..."
          sleep 5
          
          # Find Ventoy partition
          VENTOY_PART=$(lsblk -o NAME,LABEL | grep VTOYEFI | awk '{print $1}')
          VENTOY_PART=${VENTOY_PART#*└─}
          
          if [ -z "$VENTOY_PART" ]; then
            echo "Could not find Ventoy partition"
            exit 1
          fi
          
          # Mount Ventoy partition
          echo "Mounting Ventoy partition..."
          mkdir -p /mnt/ventoy
          mount /dev/$VENTOY_PART /mnt/ventoy
          
          # Copy ISOs
          echo "Copying NixOS ISO..."
          cp "$ISO_PATH/nixos-minimal-latest.iso" /mnt/ventoy/
          
          # Create recovery directory
          mkdir -p /mnt/ventoy/starfleet-recovery
          
          # Copy backups
          echo "Copying backups..."
          cp -r "$BACKUP_PATH"/* /mnt/ventoy/starfleet-recovery/
          
          # Create recovery script
          echo "Creating recovery script..."
          cat > /mnt/ventoy/starfleet-recovery/recover.sh << 'EOF'
          #!/bin/bash
          
          echo "Starfleet OS Recovery Script"
          echo "==========================="
          
          # Find latest backups
          CONFIG_BACKUP=$(ls -t configs-*.tar.gz | head -1)
          HOME_BACKUP=$(ls -t home-*.tar.gz | head -1)
          
          if [ -z "$CONFIG_BACKUP" ]; then
            echo "No configuration backup found"
            exit 1
          fi
          
          echo "Using configuration backup: $CONFIG_BACKUP"
          
          # Extract configuration backup
          mkdir -p configs
          tar -xzf "$CONFIG_BACKUP" -C configs
          
          echo "Configuration backup extracted"
          
          # Instructions
          echo ""
          echo "To recover your Starfleet OS system:"
          echo "1. Boot from the NixOS minimal ISO"
          echo "2. Mount your target disk to /mnt"
          echo "3. Copy the extracted configuration: cp -r configs/* /mnt/etc/nixos/"
          echo "4. Install NixOS: nixos-install"
          echo "5. Reboot into your recovered system"
          
          if [ -n "$HOME_BACKUP" ]; then
            echo ""
            echo "To restore home directories:"
            echo "1. Boot into your recovered system"
            echo "2. Extract home backup: tar -xzf $HOME_BACKUP -C /home"
          fi
          EOF
          
          chmod +x /mnt/ventoy/starfleet-recovery/recover.sh
          
          # Create README
          echo "Creating README..."
          cat > /mnt/ventoy/starfleet-recovery/README.txt << 'EOF'
          Starfleet OS Recovery Kit
          ========================
          
          This USB drive contains everything needed to recover your Starfleet OS system:
          
          1. NixOS minimal ISO - Boot from this to install a fresh system
          2. Configuration backups - Contains your system configuration
          3. Home directory backups - Contains your user data
          4. Database backups - Contains your database dumps
          
          To recover your system:
          1. Boot from this USB drive using Ventoy boot menu
          2. Select the NixOS minimal ISO
          3. Once booted, mount this USB drive
          4. Navigate to the starfleet-recovery directory
          5. Run ./recover.sh and follow the instructions
          
          For assistance, contact Starfleet Engineering Corps.
          EOF
          
          # Unmount Ventoy partition
          echo "Unmounting Ventoy partition..."
          umount /mnt/ventoy
          
          echo "Starfleet OS Ventoy Recovery Kit created successfully"
        ''}";
      };
    };
    
    # Recovery tools
    environment.systemPackages = with pkgs; [
      ventoy
      rsync
      gnutar
      curl
      
      # Helper scripts
      (writeScriptBin "create-recovery-kit" ''
        #!/bin/bash
        if [ $# -lt 1 ]; then
          echo "Usage: create-recovery-kit <usb_device>"
          echo "Example: create-recovery-kit /dev/sdb"
          exit 1
        fi
        
        USB_DEVICE=$1
        
        echo "Creating Starfleet OS Recovery Kit on $USB_DEVICE"
        echo "This will erase all data on the device!"
        echo "Press Ctrl+C to cancel or Enter to continue..."
        read
        
        systemctl start ventoy-recovery-kit --no-block -- "$USB_DEVICE"
        
        echo "Recovery kit creation started"
        echo "Check status with: systemctl status ventoy-recovery-kit"
      '')
      
      (writeScriptBin "backup-recovery" ''
        #!/bin/bash
        echo "Starting manual recovery backup..."
        
        systemctl start ventoy-recovery-backup
        
        echo "Recovery backup initiated"
        echo "Check status with: systemctl status ventoy-recovery-backup"
      '')
      
      (writeScriptBin "recovery-status" ''
        #!/bin/bash
        echo "Starfleet OS Recovery Status"
        echo "==========================="
        
        echo "Ventoy installation:"
        if [ -d "${cfg.recoveryPath}/ventoy/ventoy-"* ]; then
          VERSION=$(basename "${cfg.recoveryPath}/ventoy/ventoy-"* | cut -d'-' -f2)
          echo "Ventoy $VERSION is installed"
        else
          echo "Ventoy is not installed"
        fi
        
        echo ""
        echo "Backup status:"
        systemctl status ventoy-recovery-backup
        
        echo ""
        echo "Available backups:"
        ls -la ${cfg.recoveryPath}/backups
        
        echo ""
        echo "Available ISOs:"
        ls -la ${cfg.recoveryPath}/isos
      '')
    ];
  };
}