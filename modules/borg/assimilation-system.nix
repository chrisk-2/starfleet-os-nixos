{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg-assimilation;
in
{
  options.services.borg-assimilation = {
    enable = mkEnableOption "Borg Assimilation System";
    
    assimilationMethods = mkOption {
      type = types.listOf (types.enum [ "usb" "network" "wireless" "manual" ]);
      default = [ "usb" "network" ];
      description = "Enabled assimilation methods";
    };
    
    autoAssimilate = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically assimilate discovered devices";
    };
    
    securityLevel = mkOption {
      type = types.enum [ "low" "medium" "high" "maximum" ];
      default = "high";
      description = "Security level for assimilation";
    };
    
    assimilationTimeout = mkOption {
      type = types.int;
      default = 300;
      description = "Timeout in seconds for assimilation process";
    };
    
    quarantineEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable quarantine for suspicious devices";
    };
    
    adaptationEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable adaptation to new device types";
    };
  };

  config = mkIf cfg.enable {
    # Assimilation service
    systemd.services.borg-assimilation = {
      description = "Borg Assimilation System";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-assimilation-system}/bin/assimilation-system";
        Restart = "always";
        RestartSec = 5;
      };
      
      environment = {
        ASSIMILATION_METHODS = concatStringsSep "," cfg.assimilationMethods;
        AUTO_ASSIMILATE = if cfg.autoAssimilate then "true" else "false";
        SECURITY_LEVEL = cfg.securityLevel;
        ASSIMILATION_TIMEOUT = toString cfg.assimilationTimeout;
        QUARANTINE_ENABLED = if cfg.quarantineEnabled then "true" else "false";
        ADAPTATION_ENABLED = if cfg.adaptationEnabled then "true" else "false";
      };
    };
    
    # USB device monitoring
    services.udev.extraRules = ''
      # Trigger assimilation for new USB devices
      ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", RUN+="${pkgs.borg-assimilation-system}/bin/usb-assimilate '%p'"
      
      # Trigger assimilation for new storage devices
      ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", RUN+="${pkgs.borg-assimilation-system}/bin/storage-assimilate '%p'"
      
      # Trigger assimilation for new network interfaces
      ACTION=="add", SUBSYSTEM=="net", RUN+="${pkgs.borg-assimilation-system}/bin/net-assimilate '%p'"
    '';
    
    # Network device discovery
    systemd.services.borg-network-discovery = {
      description = "Borg Network Device Discovery";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-assimilation-system}/bin/network-discovery";
        Restart = "always";
        RestartSec = 30;
      };
      
      environment = {
        SCAN_INTERVAL = "300";
        SCAN_NETWORKS = "192.168.1.0/24,10.42.0.0/16";
        ADAPTATION_ENABLED = if cfg.adaptationEnabled then "true" else "false";
      };
    };
    
    # Wireless device discovery
    systemd.services.borg-wireless-discovery = mkIf (builtins.elem "wireless" cfg.assimilationMethods) {
      description = "Borg Wireless Device Discovery";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-assimilation-system}/bin/wireless-discovery";
        Restart = "always";
        RestartSec = 60;
      };
    };
    
    # Quarantine service
    systemd.services.borg-quarantine = mkIf cfg.quarantineEnabled {
      description = "Borg Assimilation Quarantine";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-assimilation-system}/bin/quarantine-manager";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Assimilation database
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "borg_assimilation" ];
      ensureUsers = [
        {
          name = "borg";
          ensurePermissions = {
            "DATABASE borg_assimilation" = "ALL PRIVILEGES";
          };
        }
      ];
    };
    
    # Required packages
    environment.systemPackages = with pkgs; [
      borg-assimilation-tools
      usbutils
      nmap
      openssh
      iw
      wireless-tools
      pciutils
      lshw
    ];
    
    # Assimilation logs
    services.journald.extraConfig = ''
      SystemMaxUse=1G
      MaxFileSec=1day
    '';
    
    # Assimilation status command
    environment.systemPackages = with pkgs; [
      (writeScriptBin "borg-assimilation-status" ''
        #!/bin/bash
        echo "Borg Assimilation System Status"
        echo "==============================="
        echo "Enabled Methods: ${concatStringsSep ", " cfg.assimilationMethods}"
        echo "Auto Assimilate: ${if cfg.autoAssimilate then "Enabled" else "Disabled"}"
        echo "Security Level: ${cfg.securityLevel}"
        echo "Quarantine: ${if cfg.quarantineEnabled then "Enabled" else "Disabled"}"
        echo "Adaptation: ${if cfg.adaptationEnabled then "Enabled" else "Disabled"}"
        echo ""
        
        echo "Active Assimilations:"
        systemctl status borg-assimilation | grep "Active:"
        
        echo ""
        echo "Recent Assimilations:"
        journalctl -u borg-assimilation --since "1 hour ago" | grep "Assimilated"
        
        echo ""
        echo "Quarantined Devices:"
        ${pkgs.borg-assimilation-system}/bin/list-quarantine
      '')
    ];
    
    # Firewall configuration
    networking.firewall.allowedTCPPorts = [
      7778  # Assimilation service
    ];
  };
}