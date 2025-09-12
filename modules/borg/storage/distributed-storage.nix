{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.storage.distributed;
in {
  options.services.borg.storage.distributed = {
    enable = mkEnableOption "Borg Collective distributed storage";
    
    type = mkOption {
      type = types.enum [ "ceph" "glusterfs" "nfs" ];
      default = "ceph";
      description = "Type of distributed storage to use";
    };
    
    mountPoints = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Mount points for distributed storage";
      example = literalExpression ''
        {
          "/collective/data" = "cephfs:data";
          "/collective/vms" = "rbd:vms";
        }
      '';
    };
    
    automount = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automount storage at boot";
    };
    
    createMountPoints = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to create mount point directories";
    };
  };
  
  config = mkIf cfg.enable {
    # Enable appropriate storage backend
    services.borg.storage = {
      ceph.enable = cfg.type == "ceph";
    };
    
    # Create mount points
    systemd.tmpfiles.rules = mkIf cfg.createMountPoints (
      mapAttrsToList (mountPoint: _: "d ${mountPoint} 0755 root root -") cfg.mountPoints
    );
    
    # Configure mount points
    fileSystems = mkIf cfg.automount (
      mapAttrs (mountPoint: source:
        let
          parts = splitString ":" source;
          storageType = elemAt parts 0;
          storageName = elemAt parts 1;
        in
        if storageType == "cephfs" then {
          device = "_netdev,name=admin,secretfile=/etc/ceph/admin.key";
          fsType = "ceph";
          options = [
            "name=admin"
            "secretfile=/etc/ceph/admin.key"
            "mount=${storageName}"
            "_netdev"
            "noatime"
          ];
        } else if storageType == "rbd" then {
          device = "/dev/rbd/${storageName}";
          fsType = "ext4";
          options = [ "defaults" "_netdev" "noatime" ];
        } else if storageType == "glusterfs" then {
          device = "${elemAt (splitString "@" storageName) 0}:/${elemAt (splitString "@" storageName) 1}";
          fsType = "glusterfs";
          options = [ "defaults" "_netdev" "noatime" ];
        } else {
          device = source;
          fsType = "nfs";
          options = [ "defaults" "_netdev" "noatime" ];
        }
      ) cfg.mountPoints
    );
    
    # Create mount/unmount services for non-automounted storage
    systemd.services = mkIf (!cfg.automount) (
      mapAttrs' (mountPoint: source:
        let
          sanitizedName = replaceStrings [ "/" ] [ "-" ] (removePrefix "/" mountPoint);
          parts = splitString ":" source;
          storageType = elemAt parts 0;
          storageName = elemAt parts 1;
          
          mountCommand = 
            if storageType == "cephfs" then
              "mount -t ceph ${config.services.ceph.global.monHost}:/ ${mountPoint} -o name=admin,secretfile=/etc/ceph/admin.key"
            else if storageType == "rbd" then
              "rbd map ${storageName} && mount /dev/rbd/${storageName} ${mountPoint}"
            else if storageType == "glusterfs" then
              "mount -t glusterfs ${elemAt (splitString "@" storageName) 0}:/${elemAt (splitString "@" storageName) 1} ${mountPoint}"
            else
              "mount -t nfs ${source} ${mountPoint}";
              
          unmountCommand = 
            if storageType == "rbd" then
              "umount ${mountPoint} && rbd unmap ${storageName}"
            else
              "umount ${mountPoint}";
        in
        nameValuePair "mount-${sanitizedName}" {
          description = "Mount ${mountPoint}";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.bash}/bin/bash -c '${mountCommand}'";
            ExecStop = "${pkgs.bash}/bin/bash -c '${unmountCommand}'";
          };
        }
      ) cfg.mountPoints
    );
    
    # Install required packages
    environment.systemPackages = with pkgs; [
      # Common tools
      nfs-utils
      
      # Ceph tools
      ceph
      ceph-common
      
      # GlusterFS tools
      glusterfs
    ];
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = mkIf config.services.borg.collective-manager.enable {
      distributedStorage = {
        enabled = true;
        type = cfg.type;
        mountPoints = cfg.mountPoints;
      };
    };
  };
}