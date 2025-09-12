{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg-adaptation;
in
{
  options.services.borg-adaptation = {
    enable = mkEnableOption "Borg Adaptation System";
    
    adaptationLevel = mkOption {
      type = types.enum [ "low" "medium" "high" "maximum" ];
      default = "medium";
      description = "Level of autonomous adaptation";
    };
    
    learningEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable machine learning for adaptation";
    };
    
    threatResponseEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automated threat response";
    };
    
    resourceAdaptationEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable adaptation to resource availability";
    };
    
    networkAdaptationEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable adaptation to network conditions";
    };
    
    serviceAdaptationEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable adaptation of services";
    };
    
    adaptationInterval = mkOption {
      type = types.int;
      default = 60;
      description = "Interval in seconds between adaptation cycles";
    };
  };

  config = mkIf cfg.enable {
    # Adaptation service
    systemd.services.borg-adaptation = {
      description = "Borg Adaptation System";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "borg-collective-manager.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-adaptation-system}/bin/adaptation-system";
        Restart = "always";
        RestartSec = 5;
      };
      
      environment = {
        ADAPTATION_LEVEL = cfg.adaptationLevel;
        LEARNING_ENABLED = if cfg.learningEnabled then "true" else "false";
        THREAT_RESPONSE = if cfg.threatResponseEnabled then "true" else "false";
        RESOURCE_ADAPTATION = if cfg.resourceAdaptationEnabled then "true" else "false";
        NETWORK_ADAPTATION = if cfg.networkAdaptationEnabled then "true" else "false";
        SERVICE_ADAPTATION = if cfg.serviceAdaptationEnabled then "true" else "false";
        ADAPTATION_INTERVAL = toString cfg.adaptationInterval;
      };
    };
    
    # Threat detection service
    systemd.services.borg-threat-detection = mkIf cfg.threatResponseEnabled {
      description = "Borg Threat Detection";
      wantedBy = [ "multi-user.target" ];
      after = [ "borg-adaptation.service" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-adaptation-system}/bin/threat-detection";
        Restart = "always";
        RestartSec = 10;
      };
    };
    
    # Resource monitoring service
    systemd.services.borg-resource-monitor = mkIf cfg.resourceAdaptationEnabled {
      description = "Borg Resource Monitor";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-adaptation-system}/bin/resource-monitor";
        Restart = "always";
        RestartSec = 15;
      };
    };
    
    # Network adaptation service
    systemd.services.borg-network-adaptation = mkIf cfg.networkAdaptationEnabled {
      description = "Borg Network Adaptation";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-adaptation-system}/bin/network-adaptation";
        Restart = "always";
        RestartSec = 20;
      };
    };
    
    # Service adaptation service
    systemd.services.borg-service-adaptation = mkIf cfg.serviceAdaptationEnabled {
      description = "Borg Service Adaptation";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-adaptation-system}/bin/service-adaptation";
        Restart = "always";
        RestartSec = 25;
      };
    };
    
    # Machine learning service
    systemd.services.borg-learning = mkIf cfg.learningEnabled {
      description = "Borg Learning System";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "borg";
        Group = "borg";
        ExecStart = "${pkgs.borg-adaptation-system}/bin/learning-system";
        Restart = "always";
        RestartSec = 30;
      };
      
      environment = {
        LEARNING_MODEL_PATH = "/var/lib/borg/models";
        LEARNING_DATA_PATH = "/var/lib/borg/data";
      };
    };
    
    # Required packages
    environment.systemPackages = with pkgs; [
      borg-adaptation-system
      python3
      python3Packages.tensorflow
      python3Packages.scikit-learn
      python3Packages.pandas
      python3Packages.numpy
      htop
      iotop
      iftop
      nload
      tcpdump
      wireshark
    ];
    
    # Adaptation logs
    services.journald.extraConfig = ''
      SystemMaxUse=2G
      MaxFileSec=3day
    '';
    
    # Adaptation status command
    environment.systemPackages = with pkgs; [
      (writeScriptBin "borg-adaptation-status" ''
        #!/bin/bash
        echo "Borg Adaptation System Status"
        echo "============================="
        echo "Adaptation Level: ${cfg.adaptationLevel}"
        echo "Learning: ${if cfg.learningEnabled then "Enabled" else "Disabled"}"
        echo "Threat Response: ${if cfg.threatResponseEnabled then "Enabled" else "Disabled"}"
        echo "Resource Adaptation: ${if cfg.resourceAdaptationEnabled then "Enabled" else "Disabled"}"
        echo "Network Adaptation: ${if cfg.networkAdaptationEnabled then "Enabled" else "Disabled"}"
        echo "Service Adaptation: ${if cfg.serviceAdaptationEnabled then "Enabled" else "Disabled"}"
        echo ""
        
        echo "Adaptation Services:"
        systemctl status borg-adaptation | grep "Active:"
        
        if [ "${if cfg.threatResponseEnabled then "true" else "false"}" = "true" ]; then
          echo ""
          echo "Threat Detection:"
          systemctl status borg-threat-detection | grep "Active:"
          echo "Recent Threats:"
          journalctl -u borg-threat-detection --since "1 hour ago" | grep "THREAT"
        fi
        
        if [ "${if cfg.resourceAdaptationEnabled then "true" else "false"}" = "true" ]; then
          echo ""
          echo "Resource Utilization:"
          ${pkgs.borg-adaptation-system}/bin/resource-status
        fi
        
        if [ "${if cfg.networkAdaptationEnabled then "true" else "false"}" = "true" ]; then
          echo ""
          echo "Network Adaptation:"
          ${pkgs.borg-adaptation-system}/bin/network-status
        fi
        
        if [ "${if cfg.serviceAdaptationEnabled then "true" else "false"}" = "true" ]; then
          echo ""
          echo "Service Adaptation:"
          ${pkgs.borg-adaptation-system}/bin/service-status
        fi
        
        if [ "${if cfg.learningEnabled then "true" else "false"}" = "true" ]; then
          echo ""
          echo "Learning System:"
          ${pkgs.borg-adaptation-system}/bin/learning-status
        fi
      '')
    ];
    
    # Create directories
    system.activationScripts.borgAdaptation = ''
      mkdir -p /var/lib/borg/models
      mkdir -p /var/lib/borg/data
      chown -R borg:borg /var/lib/borg
    '';
    
    # Firewall configuration
    networking.firewall.allowedTCPPorts = [
      7779  # Adaptation service
    ];
  };
}