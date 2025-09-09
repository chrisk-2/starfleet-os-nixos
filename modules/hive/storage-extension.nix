{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.storage-extension;
in
{
  options.services.storage-extension = {
    enable = mkEnableOption "Starfleet OS Storage Extension";
    
    storagePath = mkOption {
      type = types.str;
      default = "/var/lib/storage";
      description = "Path to storage directory";
    };
    
    enableNfs = mkOption {
      type = types.bool;
      default = true;
      description = "Enable NFS server";
    };
    
    enableSamba = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Samba server";
    };
    
    enableRaid = mkOption {
      type = types.bool;
      default = false;
      description = "Enable RAID configuration";
    };
    
    raidLevel = mkOption {
      type = types.enum [ "0" "1" "5" "6" "10" ];
      default = "5";
      description = "RAID level";
    };
  };

  config = mkIf cfg.enable {
    # Create storage directory
    systemd.tmpfiles.rules = [
      "d ${cfg.storagePath} 0755 root root -"
      "d ${cfg.storagePath}/public 0755 root root -"
      "d ${cfg.storagePath}/private 0700 root root -"
      "d ${cfg.storagePath}/backup 0700 root root -"
    ];
    
    # NFS server
    services.nfs.server = mkIf cfg.enableNfs {
      enable = true;
      
      exports = ''
        ${cfg.storagePath}/public *(rw,sync,no_subtree_check,no_root_squash)
        ${cfg.storagePath}/private 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
      '';
    };
    
    # Samba server
    services.samba = mkIf cfg.enableSamba {
      enable = true;
      
      securityType = "user";
      
      extraConfig = ''
        workgroup = STARFLEET
        server string = Starfleet OS Storage Server
        server role = standalone server
        log file = /var/log/samba/log.%m
        max log size = 50
        dns proxy = no
        map to guest = bad user
      '';
      
      shares = {
        public = {
          path = "${cfg.storagePath}/public";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "create mask" = "0644";
          "directory mask" = "0755";
        };
        
        private = {
          path = "${cfg.storagePath}/private";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
          "valid users" = "@wheel";
        };
      };
    };
    
    # RAID configuration
    services.mdadm = mkIf cfg.enableRaid {
      enable = true;
      
      arrays = {
        md0 = {
          devices = [
            "/dev/sdb"
            "/dev/sdc"
            "/dev/sdd"
          ];
          level = cfg.raidLevel;
        };
      };
    };
    
    # LVM configuration
    services.lvm = {
      enable = true;
      
      boot = {
        thin.enable = true;
      };
    };
    
    # Storage monitoring
    services.smartd = {
      enable = true;
      
      defaults = {
        monitored = true;
        autodetected = true;
        schedule = "daily";
      };
    };
    
    # Storage tools
    environment.systemPackages = with pkgs; [
      nfs-utils
      samba
      mdadm
      lvm2
      smartmontools
      hdparm
      parted
      gptfdisk
      ntfs3g
      exfat
      xfsprogs
      btrfs-progs
      
      # Helper scripts
      (writeScriptBin "storage-status" ''
        #!/bin/bash
        echo "Starfleet OS Storage Extension Status"
        echo "===================================="
        
        echo "Storage location: ${cfg.storagePath}"
        echo "Storage usage:"
        df -h ${cfg.storagePath}
        
        echo ""
        echo "Disk status:"
        lsblk -f
        
        echo ""
        if ${toString cfg.enableRaid}; then
          echo "RAID status:"
          cat /proc/mdstat
          echo ""
        fi
        
        echo "LVM status:"
        pvs
        vgs
        lvs
        
        echo ""
        echo "NFS status:"
        if ${toString cfg.enableNfs}; then
          systemctl status nfs-server
          echo ""
          echo "NFS exports:"
          exportfs -v
        else
          echo "NFS server disabled"
        fi
        
        echo ""
        echo "Samba status:"
        if ${toString cfg.enableSamba}; then
          systemctl status samba
          echo ""
          echo "Samba shares:"
          smbstatus
        else
          echo "Samba server disabled"
        fi
        
        echo ""
        echo "SMART status:"
        for disk in /dev/sd?; do
          echo "Disk $disk:"
          smartctl -H $disk
        done
      '')
      
      (writeScriptBin "storage-create-volume" ''
        #!/bin/bash
        if [ $# -lt 2 ]; then
          echo "Usage: storage-create-volume <name> <size> [filesystem]"
          echo "Example: storage-create-volume data 10G ext4"
          exit 1
        fi
        
        NAME=$1
        SIZE=$2
        FS=''${3:-ext4}
        
        echo "Creating LVM volume $NAME with size $SIZE and filesystem $FS"
        
        # Create logical volume
        lvcreate -L $SIZE -n $NAME vg0
        
        # Create filesystem
        case "$FS" in
          "ext4")
            mkfs.ext4 /dev/vg0/$NAME
            ;;
          "xfs")
            mkfs.xfs /dev/vg0/$NAME
            ;;
          "btrfs")
            mkfs.btrfs /dev/vg0/$NAME
            ;;
          *)
            echo "Unsupported filesystem: $FS"
            echo "Supported filesystems: ext4, xfs, btrfs"
            exit 1
            ;;
        esac
        
        # Create mount point
        mkdir -p ${cfg.storagePath}/$NAME
        
        # Add to fstab
        echo "/dev/vg0/$NAME ${cfg.storagePath}/$NAME $FS defaults 0 2" >> /etc/fstab
        
        # Mount volume
        mount ${cfg.storagePath}/$NAME
        
        echo "Volume $NAME created and mounted at ${cfg.storagePath}/$NAME"
      '')
    ];
  };
}