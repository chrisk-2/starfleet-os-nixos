{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.virtualization.proxmox;
in {
  options.services.borg.virtualization.proxmox = {
    enable = mkEnableOption "Borg Collective Proxmox VE integration";
    
    role = mkOption {
      type = types.enum [ "server" "client" ];
      default = "client";
      description = "Role of this node in the Proxmox cluster";
    };
    
    clusterName = mkOption {
      type = types.str;
      default = "borg-collective";
      description = "Name of the Proxmox cluster";
    };
    
    nodeAddress = mkOption {
      type = types.str;
      description = "IP address of this node";
    };
    
    serverNodes = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of server node addresses in the cluster";
    };
  };
  
  config = mkIf cfg.enable {
    # Install Proxmox VE packages
    environment.systemPackages = with pkgs; [
      # Core Proxmox packages
      pve-manager
      pve-container
      pve-firewall
      pve-ha-manager
      qemu-server
      ksm
      
      # Ceph integration
      ceph
      ceph-common
      
      # Storage utilities
      zfsutils
      lvm2
      
      # Network utilities
      bridge-utils
      ethtool
      iptables
    ];
    
    # Configure Proxmox services
    services.qemu-server.enable = true;
    services.pve-cluster = {
      enable = true;
      clusterName = cfg.clusterName;
      nodeAddress = cfg.nodeAddress;
    };
    
    # Configure networking for Proxmox
    networking.firewall.allowedTCPPorts = [
      8006  # Proxmox web UI
      3128  # Proxmox proxy
      111   # rpcbind
      5900  # VNC
      5404  # corosync
      5405  # corosync
      22    # SSH
    ];
    
    # Configure cluster setup based on role
    systemd.services.pve-cluster-setup = mkIf (cfg.role == "server") {
      description = "Proxmox VE cluster setup";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      script = ''
        # Create cluster if it doesn't exist
        if ! pvecm status &>/dev/null; then
          pvecm create ${cfg.clusterName}
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Configure client nodes to join cluster
    systemd.services.pve-cluster-join = mkIf (cfg.role == "client" && cfg.serverNodes != []) {
      description = "Join Proxmox VE cluster";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      script = ''
        # Join cluster if not already a member
        if ! pvecm status &>/dev/null; then
          pvecm add ${builtins.elemAt cfg.serverNodes 0} --force
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Enable required kernel modules
    boot.kernelModules = [
      "kvm"
      "kvm_intel"  # or kvm_amd for AMD processors
      "vhost_net"
      "vhost_scsi"
      "vhost_vsock"
      "tun"
      "zfs"
    ];
    
    # Configure system for virtualization
    virtualisation = {
      libvirtd.enable = true;
      lxc.enable = true;
      lxd.enable = true;
    };
    
    # Enable required services
    services.corosync.enable = true;
    services.pveproxy.enable = true;
    services.pvedaemon.enable = true;
    services.spiceproxy.enable = true;
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = mkIf config.services.borg.collective-manager.enable {
      virtualizationEnabled = true;
      virtualizationSystem = "proxmox";
      virtualizationEndpoint = "https://${cfg.nodeAddress}:8006/api2/json";
    };
  };
}