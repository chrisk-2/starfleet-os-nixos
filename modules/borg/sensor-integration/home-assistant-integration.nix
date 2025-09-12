{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.sensors.homeAssistant;
in {
  options.services.borg.sensors.homeAssistant = {
    enable = mkEnableOption "Borg Collective Home Assistant integration";
    
    deployment = mkOption {
      type = types.enum [ "local" "remote" ];
      default = "remote";
      description = "Whether Home Assistant is deployed locally or remotely";
    };
    
    url = mkOption {
      type = types.str;
      default = "http://homeassistant.local:8123";
      description = "URL of Home Assistant instance";
    };
    
    token = mkOption {
      type = types.str;
      default = "";
      description = "Long-lived access token for Home Assistant API";
    };
    
    config = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional Home Assistant configuration";
    };
    
    borgIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Borg Collective integration in Home Assistant";
    };
    
    mqttIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable MQTT integration in Home Assistant";
    };
    
    mqttBroker = mkOption {
      type = types.str;
      default = "localhost";
      description = "MQTT broker address";
    };
    
    mqttPort = mkOption {
      type = types.int;
      default = 1883;
      description = "MQTT broker port";
    };
    
    mqttUsername = mkOption {
      type = types.str;
      default = "homeassistant";
      description = "MQTT username";
    };
    
    mqttPassword = mkOption {
      type = types.str;
      default = "";
      description = "MQTT password";
    };
  };
  
  config = mkIf cfg.enable {
    # Install Home Assistant if deployed locally
    services.home-assistant = mkIf (cfg.deployment == "local") {
      enable = true;
      openFirewall = true;
      
      # Basic configuration
      config = {
        # Core configuration
        homeassistant = {
          name = "Borg Collective";
          latitude = "!secret latitude";
          longitude = "!secret longitude";
          elevation = 0;
          unit_system = "metric";
          time_zone = "UTC";
          external_url = cfg.url;
        };
        
        # HTTP configuration
        http = {
          server_port = 8123;
          use_x_forwarded_for = true;
          trusted_proxies = [ "127.0.0.1" "::1" ];
        };
        
        # Default configuration
        default_config = {};
        
        # MQTT integration
        mqtt = mkIf cfg.mqttIntegration {
          broker = cfg.mqttBroker;
          port = cfg.mqttPort;
          username = cfg.mqttUsername;
          password = cfg.mqttPassword;
          discovery = true;
          discovery_prefix = "homeassistant";
        };
        
        # Borg Collective integration
        rest = mkIf cfg.borgIntegration {
          - resource = "http://localhost:8080/api/collective/status";
            scan_interval = 30;
            sensor = {
              - name = "Borg Collective Status";
                value_template = "{{ value_json.status }}";
            };
        };
        
        # Sensors
        sensor = [
          {
            platform = "systemmonitor";
            resources = [
              { type = "disk_use_percent"; arg = "/"; }
              { type = "memory_use_percent"; }
              { type = "processor_use"; }
              { type = "last_boot"; }
            ];
          }
        ];
        
        # Automations
        automation = [
          {
            alias = "Notify on Borg Collective Status Change";
            trigger = {
              platform = "state";
              entity_id = "sensor.borg_collective_status";
            };
            action = {
              service = "persistent_notification.create";
              data = {
                title = "Borg Collective Status Change";
                message = "Status changed to {{ states('sensor.borg_collective_status') }}";
              };
            };
          }
        ];
        
        # Additional user configuration
        recorder = {
          purge_keep_days = 30;
          commit_interval = 1;
        };
        
        # Include user-provided configuration
      } // cfg.config;
    };
    
    # Install Home Assistant CLI for remote deployments
    environment.systemPackages = mkIf (cfg.deployment == "remote") [
      pkgs.home-assistant-cli
    ];
    
    # Configure Home Assistant CLI for remote deployments
    environment.etc."home-assistant-cli/config" = mkIf (cfg.deployment == "remote") {
      text = ''
        [DEFAULT]
        server = ${cfg.url}
        token = ${cfg.token}
      '';
      mode = "0600";
    };
    
    # Create service for Home Assistant integration
    systemd.services.borg-homeassistant-integration = mkIf (cfg.deployment == "remote" && cfg.borgIntegration) {
      description = "Borg Collective Home Assistant Integration";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      script = ''
        # Create sensor in Home Assistant
        ${pkgs.curl}/bin/curl -X POST \
          -H "Authorization: Bearer ${cfg.token}" \
          -H "Content-Type: application/json" \
          ${cfg.url}/api/services/rest/reload \
          -d '{}'
        
        # Register Borg Collective entity
        ${pkgs.curl}/bin/curl -X POST \
          -H "Authorization: Bearer ${cfg.token}" \
          -H "Content-Type: application/json" \
          ${cfg.url}/api/states/sensor.borg_collective_status \
          -d '{"state": "online", "attributes": {"friendly_name": "Borg Collective Status", "icon": "mdi:robot"}}'
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Create service for periodic status updates
    systemd.services.borg-homeassistant-status-updater = mkIf (cfg.deployment == "remote" && cfg.borgIntegration) {
      description = "Borg Collective Home Assistant Status Updater";
      wantedBy = [ "multi-user.target" ];
      after = [ "borg-homeassistant-integration.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = pkgs.writeScript "homeassistant-status-updater" ''
          #!${pkgs.bash}/bin/bash
          
          while true; do
            # Get Borg Collective status
            STATUS=$(${pkgs.curl}/bin/curl -s http://localhost:8080/api/collective/status | ${pkgs.jq}/bin/jq -r '.status')
            
            # Update Home Assistant entity
            ${pkgs.curl}/bin/curl -X POST \
              -H "Authorization: Bearer ${cfg.token}" \
              -H "Content-Type: application/json" \
              ${cfg.url}/api/states/sensor.borg_collective_status \
              -d "{&quot;state&quot;: &quot;$STATUS&quot;, &quot;attributes&quot;: {&quot;friendly_name&quot;: &quot;Borg Collective Status&quot;, &quot;icon&quot;: &quot;mdi:robot&quot;}}"
            
            # Wait before next update
            sleep 60
          done
        '';
        Restart = "always";
        RestartSec = "10s";
      };
    };
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = mkIf config.services.borg.collective-manager.enable {
      sensorIntegration = {
        enabled = true;
        type = "home-assistant";
        endpoint = cfg.url;
        token = cfg.token;
      };
    };
  };
}