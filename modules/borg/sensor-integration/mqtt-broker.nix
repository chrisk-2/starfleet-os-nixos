{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.sensors.mqtt;
  
  # Define the user type
  userType = types.submodule {
    options = {
      password = mkOption {
        type = types.str;
        description = "User password";
      };
      
      acl = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Access control list for user";
        example = [ "readwrite sensors/#" "read #" ];
      };
    };
  };
in {
  options.services.borg.sensors.mqtt = {
    enable = mkEnableOption "Borg Collective MQTT broker";
    
    deployment = mkOption {
      type = types.enum [ "local" "kubernetes" ];
      default = "local";
      description = "Whether MQTT broker is deployed locally or in Kubernetes";
    };
    
    port = mkOption {
      type = types.int;
      default = 1883;
      description = "MQTT broker port";
    };
    
    websocketPort = mkOption {
      type = types.int;
      default = 9001;
      description = "MQTT websocket port";
    };
    
    enableWebsockets = mkOption {
      type = types.bool;
      default = true;
      description = "Enable MQTT over WebSockets";
    };
    
    allowAnonymous = mkOption {
      type = types.bool;
      default = false;
      description = "Allow anonymous access to MQTT broker";
    };
    
    users = mkOption {
      type = types.attrsOf userType;
      default = {};
      description = "MQTT users";
      example = literalExpression ''
        {
          "borg-queen" = {
            password = "borg-queen-password";
            acl = [ "readwrite #" ];
          };
          "borg-drone" = {
            password = "borg-drone-password";
            acl = [ "read #" "write sensors/#" ];
          };
        }
      '';
    };
    
    persistentData = mkOption {
      type = types.bool;
      default = true;
      description = "Enable persistent data storage";
    };
    
    dataDirectory = mkOption {
      type = types.str;
      default = "/var/lib/mosquitto";
      description = "Directory for persistent data storage";
    };
    
    logType = mkOption {
      type = types.enum [ "stdout" "stderr" "syslog" "topic" "file" "none" ];
      default = "stderr";
      description = "MQTT broker log type";
    };
    
    logFile = mkOption {
      type = types.str;
      default = "/var/log/mosquitto/mosquitto.log";
      description = "MQTT broker log file";
    };
    
    logLevel = mkOption {
      type = types.enum [ "debug" "info" "notice" "warning" "error" "crit" "alert" "emerg" ];
      default = "info";
      description = "MQTT broker log level";
    };
    
    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional Mosquitto configuration";
    };
  };
  
  config = mkIf cfg.enable {
    # Install Mosquitto MQTT broker for local deployment
    services.mosquitto = mkIf (cfg.deployment == "local") {
      enable = true;
      
      # Basic configuration
      host = "0.0.0.0";
      port = cfg.port;
      allowAnonymous = cfg.allowAnonymous;
      
      # User configuration
      users = mapAttrsToList (name: user: {
        inherit name;
        password = user.password;
        acl = user.acl;
      }) cfg.users;
      
      # Additional settings
      settings = {
        persistence = cfg.persistentData;
        persistence_location = cfg.dataDirectory;
        log_dest = cfg.logType;
        log_type = "all";
        connection_messages = true;
        log_timestamp = true;
        allow_zero_length_clientid = true;
        
        # WebSockets configuration
        listener = optional cfg.enableWebsockets cfg.websocketPort;
        protocol = optional cfg.enableWebsockets "websockets";
      };
      
      # Extra configuration
      extraConf = cfg.extraConfig;
    };
    
    # Create log directory
    systemd.tmpfiles.rules = mkIf (cfg.deployment == "local" && cfg.logType == "file") [
      "d ${dirOf cfg.logFile} 0755 mosquitto mosquitto -"
    ];
    
    # Deploy Mosquitto in Kubernetes
    systemd.services.deploy-mqtt-broker = mkIf (cfg.deployment == "kubernetes") {
      description = "Deploy MQTT broker to Kubernetes";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" ];
      path = with pkgs; [ kubectl ];
      script = ''
        # Wait for Kubernetes API to be available
        until kubectl get nodes &>/dev/null; do
          echo "Waiting for Kubernetes API..."
          sleep 5
        done
        
        # Create namespace if it doesn't exist
        kubectl create namespace borg-collective --dry-run=client -o yaml | kubectl apply -f -
        
        # Create ConfigMap for Mosquitto configuration
        kubectl create configmap mosquitto-config -n borg-collective --from-literal=mosquitto.conf="
        # Basic configuration
        listener ${toString cfg.port}
        allow_anonymous ${if cfg.allowAnonymous then "true" else "false"}
        password_file /mosquitto/config/passwd
        
        # Persistence
        persistence ${if cfg.persistentData then "true" else "false"}
        persistence_location /mosquitto/data/
        
        # Logging
        log_dest ${cfg.logType}
        log_type all
        connection_messages true
        log_timestamp true
        
        # WebSockets
        ${optionalString cfg.enableWebsockets ''
        listener ${toString cfg.websocketPort}
        protocol websockets
        ''}
        
        # Extra configuration
        ${cfg.extraConfig}
        " --dry-run=client -o yaml | kubectl apply -f -
        
        # Create Secret for Mosquitto password file
        kubectl create secret generic mosquitto-passwd -n borg-collective --from-literal=passwd="
        ${concatStringsSep "\n" (mapAttrsToList (name: user: "${name}:${user.password}") cfg.users)}
        " --dry-run=client -o yaml | kubectl apply -f -
        
        # Create ACL file ConfigMap
        kubectl create configmap mosquitto-acl -n borg-collective --from-literal=acl="
        # ACL configuration
        ${concatStringsSep "\n" (flatten (mapAttrsToList (name: user: 
          map (aclEntry: "user ${name}\n${aclEntry}") user.acl
        ) cfg.users))}
        " --dry-run=client -o yaml | kubectl apply -f -
        
        # Deploy Mosquitto
        kubectl apply -f - <<EOF
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: mosquitto
          namespace: borg-collective
        spec:
          replicas: 1
          selector:
            matchLabels:
              app: mosquitto
          template:
            metadata:
              labels:
                app: mosquitto
            spec:
              containers:
              - name: mosquitto
                image: eclipse-mosquitto:2.0
                ports:
                - containerPort: ${toString cfg.port}
                  name: mqtt
                ${optionalString cfg.enableWebsockets ''
                - containerPort: ${toString cfg.websocketPort}
                  name: websockets
                ''}
                volumeMounts:
                - name: mosquitto-config
                  mountPath: /mosquitto/config/mosquitto.conf
                  subPath: mosquitto.conf
                - name: mosquitto-passwd
                  mountPath: /mosquitto/config/passwd
                  subPath: passwd
                - name: mosquitto-acl
                  mountPath: /mosquitto/config/acl
                  subPath: acl
                - name: mosquitto-data
                  mountPath: /mosquitto/data
                - name: mosquitto-log
                  mountPath: /mosquitto/log
              volumes:
              - name: mosquitto-config
                configMap:
                  name: mosquitto-config
              - name: mosquitto-passwd
                secret:
                  secretName: mosquitto-passwd
              - name: mosquitto-acl
                configMap:
                  name: mosquitto-acl
              - name: mosquitto-data
                persistentVolumeClaim:
                  claimName: mosquitto-data
              - name: mosquitto-log
                persistentVolumeClaim:
                  claimName: mosquitto-log
        ---
        apiVersion: v1
        kind: Service
        metadata:
          name: mosquitto
          namespace: borg-collective
        spec:
          selector:
            app: mosquitto
          ports:
          - port: ${toString cfg.port}
            targetPort: ${toString cfg.port}
            name: mqtt
          ${optionalString cfg.enableWebsockets ''
          - port: ${toString cfg.websocketPort}
            targetPort: ${toString cfg.websocketPort}
            name: websockets
          ''}
        ---
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
          name: mosquitto-data
          namespace: borg-collective
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
        ---
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
          name: mosquitto-log
          namespace: borg-collective
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
        EOF
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Configure firewall for MQTT
    networking.firewall.allowedTCPPorts = mkIf (cfg.deployment == "local") ([
      cfg.port
    ] ++ optional cfg.enableWebsockets cfg.websocketPort);
    
    # Install MQTT client tools
    environment.systemPackages = with pkgs; [
      mosquitto
    ];
    
    # Register MQTT broker with Consul if service discovery is enabled
    services.borg.discovery.registry.services = mkIf (cfg.deployment == "local" && config.services.borg.discovery.registry.enable) {
      "mqtt-broker" = {
        name = "mqtt-broker";
        tags = [ "mqtt" "broker" "iot" ];
        address = config.networking.hostName;
        port = cfg.port;
        checks = [
          {
            type = "tcp";
            target = "localhost:${toString cfg.port}";
            interval = "30s";
          }
        ];
      };
    };
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = mkIf config.services.borg.collective-manager.enable {
      mqttEnabled = true;
      mqttBroker = cfg.deployment == "local" ? "localhost" : "mosquitto.borg-collective.svc.cluster.local";
      mqttPort = cfg.port;
      mqttTopics = [
        "sensors/#"
        "cameras/#"
        "alarms/#"
        "borg/#"
      ];
    };
  };
}