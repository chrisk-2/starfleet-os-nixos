{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.storage.ceph;
in {
  options.services.borg.storage.ceph = {
    enable = mkEnableOption "Borg Collective Ceph integration";
    
    role = mkOption {
      type = types.enum [ "mon" "osd" "mgr" "mds" "client" "all" ];
      default = "client";
      description = "Role of this node in the Ceph cluster";
    };
    
    monitorNodes = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of monitor node addresses";
    };
    
    publicNetwork = mkOption {
      type = types.str;
      default = "10.42.0.0/24";
      description = "Public network for Ceph";
    };
    
    clusterNetwork = mkOption {
      type = types.str;
      default = "10.42.1.0/24";
      description = "Cluster network for Ceph";
    };
    
    osdDevices = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of devices to use for OSDs";
    };
    
    fsid = mkOption {
      type = types.str;
      default = "00000000-0000-0000-0000-000000000000";
      description = "Ceph cluster FSID";
    };
    
    monInitialMembers = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Initial monitor members";
    };
  };
  
  config = mkIf cfg.enable {
    # Install Ceph packages
    environment.systemPackages = with pkgs; [
      ceph
      ceph-common
      lvm2
      xfsprogs
      parted
      gdisk
      smartmontools
    ];
    
    # Configure Ceph services based on role
    services.ceph = {
      enable = true;
      global = {
        fsid = cfg.fsid;
        monHost = concatStringsSep "," cfg.monitorNodes;
        public_network = cfg.publicNetwork;
        cluster_network = cfg.clusterNetwork;
        auth_cluster_required = "cephx";
        auth_service_required = "cephx";
        auth_client_required = "cephx";
        osd_pool_default_size = "2";
        osd_pool_default_min_size = "1";
        osd_pool_default_pg_num = "128";
        osd_pool_default_pgp_num = "128";
      };
      
      mon = mkIf (cfg.role == "mon" || cfg.role == "all") {
        enable = true;
        daemons = [ config.networking.hostName ];
        global = {
          mon_initial_members = concatStringsSep "," cfg.monInitialMembers;
        };
      };
      
      mgr = mkIf (cfg.role == "mgr" || cfg.role == "all") {
        enable = true;
        daemons = [ config.networking.hostName ];
      };
      
      osd = mkIf (cfg.role == "osd" || cfg.role == "all") {
        enable = true;
        daemons = map (dev: builtins.baseNameOf dev) cfg.osdDevices;
        extraConfig = {
          "osd max backfills" = "1";
          "osd recovery max active" = "1";
          "osd recovery op priority" = "1";
          "osd journal size" = "1024";
          "osd pool default crush rule" = "0";
        };
      };
      
      mds = mkIf (cfg.role == "mds" || cfg.role == "all") {
        enable = true;
        daemons = [ config.networking.hostName ];
      };
      
      client = mkIf (cfg.role == "client" || cfg.role == "all") {
        enable = true;
      };
    };
    
    # Configure firewall for Ceph
    networking.firewall.allowedTCPPorts = [
      6789  # Ceph Monitor
      6800  # Ceph OSD
      6801  # Ceph OSD
      6802  # Ceph OSD
      6803  # Ceph OSD
      6804  # Ceph OSD
      6805  # Ceph OSD
      3300  # Ceph Manager
    ];
    
    # Setup OSD devices
    systemd.services.ceph-osd-setup = mkIf ((cfg.role == "osd" || cfg.role == "all") && cfg.osdDevices != []) {
      description = "Setup Ceph OSD devices";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      script = ''
        # For each OSD device
        ${concatMapStrings (dev: ''
          # Check if device is already an OSD
          if ! ceph-volume lvm list | grep -q ${dev}; then
            # Prepare the device
            ceph-volume lvm prepare --data ${dev}
          fi
        '') cfg.osdDevices}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Setup CephFS
    systemd.services.ceph-fs-setup = mkIf (cfg.role == "mon" || cfg.role == "all") {
      description = "Setup CephFS";
      wantedBy = [ "multi-user.target" ];
      after = [ "ceph.target" ];
      script = ''
        # Create pools if they don't exist
        if ! ceph osd pool ls | grep -q "cephfs_data"; then
          ceph osd pool create cephfs_data 128
        fi
        
        if ! ceph osd pool ls | grep -q "cephfs_metadata"; then
          ceph osd pool create cephfs_metadata 32
        fi
        
        # Create filesystem if it doesn't exist
        if ! ceph fs ls | grep -q "borgfs"; then
          ceph fs new borgfs cephfs_metadata cephfs_data
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = mkIf config.services.borg.collective-manager.enable {
      storageEnabled = true;
      storageSystem = "ceph";
      storagePools = {
        vms = {
          type = "rbd";
          size = "3TB";
          replicas = 2;
        };
        data = {
          type = "cephfs";
          size = "2TB";
          replicas = 2;
        };
      };
    };
  };
}