{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.orchestration.services;
in {
  options.services.borg.orchestration.services = {
    enable = mkEnableOption "Borg Collective container services";
    
    namespace = mkOption {
      type = types.str;
      default = "borg-collective";
      description = "Kubernetes namespace for Borg Collective services";
    };
    
    lcarsApi = mkOption {
      type = types.bool;
      default = true;
      description = "Deploy LCARS API server";
    };
    
    collectiveManager = mkOption {
      type = types.bool;
      default = true;
      description = "Deploy Collective Manager service";
    };
    
    monitoring = mkOption {
      type = types.bool;
      default = true;
      description = "Deploy Prometheus and Grafana for monitoring";
    };
    
    neo4j = mkOption {
      type = types.bool;
      default = false;
      description = "Deploy Neo4j graph database";
    };
    
    assimilationService = mkOption {
      type = types.bool;
      default = true;
      description = "Deploy Assimilation Service";
    };
    
    adaptationService = mkOption {
      type = types.bool;
      default = true;
      description = "Deploy Adaptation Service";
    };
    
    lcarsApiImage = mkOption {
      type = types.str;
      default = "localhost:5000/lcars-api:latest";
      description = "Docker image for LCARS API";
    };
    
    collectiveManagerImage = mkOption {
      type = types.str;
      default = "localhost:5000/collective-manager:latest";
      description = "Docker image for Collective Manager";
    };
    
    assimilationServiceImage = mkOption {
      type = types.str;
      default = "localhost:5000/assimilation-service:latest";
      description = "Docker image for Assimilation Service";
    };
    
    adaptationServiceImage = mkOption {
      type = types.str;
      default = "localhost:5000/adaptation-service:latest";
      description = "Docker image for Adaptation Service";
    };
  };
  
  config = mkIf cfg.enable {
    # Ensure Kubernetes is enabled
    services.borg.orchestration.kubernetes.enable = true;
    services.borg.orchestration.kubernetes.role = "master";
    
    # Deploy services
    systemd.services.deploy-borg-services = {
      description = "Deploy Borg Collective services to Kubernetes";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" ];
      path = with pkgs; [ kubectl ];
      script = ''
        # Wait for Kubernetes API to be available
        until kubectl get nodes &>/dev/null; do
          echo "Waiting for Kubernetes API..."
          sleep 5
        done
        
        # Create namespace
        kubectl create namespace ${cfg.namespace} --dry-run=client -o yaml | kubectl apply -f -
        
        # Deploy LCARS API
        ${optionalString cfg.lcarsApi ''
          kubectl apply -f - <<EOF
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: lcars-api
            namespace: ${cfg.namespace}
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: lcars-api
            template:
              metadata:
                labels:
                  app: lcars-api
              spec:
                containers:
                - name: lcars-api
                  image: ${cfg.lcarsApiImage}
                  ports:
                  - containerPort: 8080
                  env:
                  - name: CONSUL_HTTP_ADDR
                    value: "consul-server.${cfg.namespace}.svc.cluster.local:8500"
                  - name: MQTT_BROKER
                    value: "mosquitto.${cfg.namespace}.svc.cluster.local:1883"
                  resources:
                    limits:
                      cpu: "1"
                      memory: "1Gi"
                    requests:
                      cpu: "500m"
                      memory: "512Mi"
                  livenessProbe:
                    httpGet:
                      path: /health
                      port: 8080
                    initialDelaySeconds: 30
                    periodSeconds: 10
                  readinessProbe:
                    httpGet:
                      path: /health
                      port: 8080
                    initialDelaySeconds: 5
                    periodSeconds: 5
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: lcars-api
            namespace: ${cfg.namespace}
          spec:
            selector:
              app: lcars-api
            ports:
            - port: 8080
              targetPort: 8080
          ---
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: lcars-api
            namespace: ${cfg.namespace}
            annotations:
              kubernetes.io/ingress.class: "nginx"
          spec:
            rules:
            - host: lcars-api.borg-collective.local
              http:
                paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: lcars-api
                      port:
                        number: 8080
          EOF
        ''}
        
        # Deploy Collective Manager
        ${optionalString cfg.collectiveManager ''
          kubectl apply -f - <<EOF
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: collective-manager
            namespace: ${cfg.namespace}
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: collective-manager
            template:
              metadata:
                labels:
                  app: collective-manager
              spec:
                containers:
                - name: collective-manager
                  image: ${cfg.collectiveManagerImage}
                  ports:
                  - containerPort: 8080
                  env:
                  - name: ROLE
                    value: "queen"
                  - name: CONSUL_HTTP_ADDR
                    value: "consul-server.${cfg.namespace}.svc.cluster.local:8500"
                  - name: MQTT_BROKER
                    value: "mosquitto.${cfg.namespace}.svc.cluster.local:1883"
                  resources:
                    limits:
                      cpu: "1"
                      memory: "2Gi"
                    requests:
                      cpu: "500m"
                      memory: "1Gi"
                  livenessProbe:
                    httpGet:
                      path: /health
                      port: 8080
                    initialDelaySeconds: 30
                    periodSeconds: 10
                  readinessProbe:
                    httpGet:
                      path: /health
                      port: 8080
                    initialDelaySeconds: 5
                    periodSeconds: 5
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: collective-manager
            namespace: ${cfg.namespace}
          spec:
            selector:
              app: collective-manager
            ports:
            - port: 8080
              targetPort: 8080
          ---
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: collective-manager
            namespace: ${cfg.namespace}
            annotations:
              kubernetes.io/ingress.class: "nginx"
          spec:
            rules:
            - host: collective-manager.borg-collective.local
              http:
                paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: collective-manager
                      port:
                        number: 8080
          EOF
        ''}
        
        # Deploy Assimilation Service
        ${optionalString cfg.assimilationService ''
          kubectl apply -f - <<EOF
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: assimilation-service
            namespace: ${cfg.namespace}
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: assimilation-service
            template:
              metadata:
                labels:
                  app: assimilation-service
              spec:
                containers:
                - name: assimilation-service
                  image: ${cfg.assimilationServiceImage}
                  ports:
                  - containerPort: 8080
                  env:
                  - name: ROLE
                    value: "queen"
                  - name: CONSUL_HTTP_ADDR
                    value: "consul-server.${cfg.namespace}.svc.cluster.local:8500"
                  - name: MQTT_BROKER
                    value: "mosquitto.${cfg.namespace}.svc.cluster.local:1883"
                  - name: COLLECTIVE_MANAGER_URL
                    value: "http://collective-manager.${cfg.namespace}.svc.cluster.local:8080"
                  resources:
                    limits:
                      cpu: "1"
                      memory: "1Gi"
                    requests:
                      cpu: "500m"
                      memory: "512Mi"
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: assimilation-service
            namespace: ${cfg.namespace}
          spec:
            selector:
              app: assimilation-service
            ports:
            - port: 8080
              targetPort: 8080
          EOF
        ''}
        
        # Deploy Adaptation Service
        ${optionalString cfg.adaptationService ''
          kubectl apply -f - <<EOF
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: adaptation-service
            namespace: ${cfg.namespace}
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: adaptation-service
            template:
              metadata:
                labels:
                  app: adaptation-service
              spec:
                containers:
                - name: adaptation-service
                  image: ${cfg.adaptationServiceImage}
                  ports:
                  - containerPort: 8080
                  env:
                  - name: ROLE
                    value: "central"
                  - name: CONSUL_HTTP_ADDR
                    value: "consul-server.${cfg.namespace}.svc.cluster.local:8500"
                  - name: MQTT_BROKER
                    value: "mosquitto.${cfg.namespace}.svc.cluster.local:1883"
                  - name: COLLECTIVE_MANAGER_URL
                    value: "http://collective-manager.${cfg.namespace}.svc.cluster.local:8080"
                  resources:
                    limits:
                      cpu: "1"
                      memory: "1Gi"
                    requests:
                      cpu: "500m"
                      memory: "512Mi"
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: adaptation-service
            namespace: ${cfg.namespace}
          spec:
            selector:
              app: adaptation-service
            ports:
            - port: 8080
              targetPort: 8080
          EOF
        ''}
        
        # Deploy Prometheus and Grafana
        ${optionalString cfg.monitoring ''
          kubectl apply -f - <<EOF
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: prometheus
            namespace: ${cfg.namespace}
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: prometheus
            template:
              metadata:
                labels:
                  app: prometheus
              spec:
                containers:
                - name: prometheus
                  image: prom/prometheus:latest
                  ports:
                  - containerPort: 9090
                  volumeMounts:
                  - name: prometheus-config
                    mountPath: /etc/prometheus/prometheus.yml
                    subPath: prometheus.yml
                  - name: prometheus-data
                    mountPath: /prometheus
                  resources:
                    limits:
                      cpu: "1"
                      memory: "2Gi"
                    requests:
                      cpu: "500m"
                      memory: "1Gi"
                volumes:
                - name: prometheus-config
                  configMap:
                    name: prometheus-config
                - name: prometheus-data
                  persistentVolumeClaim:
                    claimName: prometheus-data
          ---
          apiVersion: v1
          kind: ConfigMap
          metadata:
            name: prometheus-config
            namespace: ${cfg.namespace}
          data:
            prometheus.yml: |
              global:
                scrape_interval: 15s
                evaluation_interval: 15s
              scrape_configs:
                - job_name: 'kubernetes-apiservers'
                  kubernetes_sd_configs:
                  - role: endpoints
                  scheme: https
                  tls_config:
                    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
                  relabel_configs:
                  - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
                    action: keep
                    regex: default;kubernetes;https
                - job_name: 'borg-collective'
                  static_configs:
                  - targets: ['collective-manager.${cfg.namespace}.svc.cluster.local:8080', 'lcars-api.${cfg.namespace}.svc.cluster.local:8080']
          ---
          apiVersion: v1
          kind: PersistentVolumeClaim
          metadata:
            name: prometheus-data
            namespace: ${cfg.namespace}
          spec:
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 10Gi
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: prometheus
            namespace: ${cfg.namespace}
          spec:
            selector:
              app: prometheus
            ports:
            - port: 9090
              targetPort: 9090
          ---
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: grafana
            namespace: ${cfg.namespace}
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: grafana
            template:
              metadata:
                labels:
                  app: grafana
              spec:
                containers:
                - name: grafana
                  image: grafana/grafana:latest
                  ports:
                  - containerPort: 3000
                  env:
                  - name: GF_SECURITY_ADMIN_PASSWORD
                    value: "borg-collective"
                  - name: GF_USERS_ALLOW_SIGN_UP
                    value: "false"
                  volumeMounts:
                  - name: grafana-data
                    mountPath: /var/lib/grafana
                  resources:
                    limits:
                      cpu: "1"
                      memory: "1Gi"
                    requests:
                      cpu: "500m"
                      memory: "512Mi"
                volumes:
                - name: grafana-data
                  persistentVolumeClaim:
                    claimName: grafana-data
          ---
          apiVersion: v1
          kind: PersistentVolumeClaim
          metadata:
            name: grafana-data
            namespace: ${cfg.namespace}
          spec:
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 5Gi
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: grafana
            namespace: ${cfg.namespace}
          spec:
            selector:
              app: grafana
            ports:
            - port: 3000
              targetPort: 3000
          ---
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: grafana
            namespace: ${cfg.namespace}
            annotations:
              kubernetes.io/ingress.class: "nginx"
          spec:
            rules:
            - host: grafana.borg-collective.local
              http:
                paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: grafana
                      port:
                        number: 3000
          EOF
        ''}
        
        # Deploy Neo4j
        ${optionalString cfg.neo4j ''
          kubectl apply -f - <<EOF
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: neo4j
            namespace: ${cfg.namespace}
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: neo4j
            template:
              metadata:
                labels:
                  app: neo4j
              spec:
                containers:
                - name: neo4j
                  image: neo4j:latest
                  ports:
                  - containerPort: 7474
                    name: http
                  - containerPort: 7687
                    name: bolt
                  env:
                  - name: NEO4J_AUTH
                    value: "neo4j/borg-collective"
                  - name: NEO4J_apoc_export_file_enabled
                    value: "true"
                  - name: NEO4J_apoc_import_file_enabled
                    value: "true"
                  - name: NEO4J_apoc_import_file_use__neo4j__config
                    value: "true"
                  volumeMounts:
                  - name: neo4j-data
                    mountPath: /data
                  resources:
                    limits:
                      cpu: "2"
                      memory: "4Gi"
                    requests:
                      cpu: "1"
                      memory: "2Gi"
                volumes:
                - name: neo4j-data
                  persistentVolumeClaim:
                    claimName: neo4j-data
          ---
          apiVersion: v1
          kind: PersistentVolumeClaim
          metadata:
            name: neo4j-data
            namespace: ${cfg.namespace}
          spec:
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 10Gi
          ---
          apiVersion: v1
          kind: Service
          metadata:
            name: neo4j
            namespace: ${cfg.namespace}
          spec:
            selector:
              app: neo4j
            ports:
            - port: 7474
              targetPort: 7474
              name: http
            - port: 7687
              targetPort: 7687
              name: bolt
          ---
          apiVersion: networking.k8s.io/v1
          kind: Ingress
          metadata:
            name: neo4j
            namespace: ${cfg.namespace}
            annotations:
              kubernetes.io/ingress.class: "nginx"
          spec:
            rules:
            - host: neo4j.borg-collective.local
              http:
                paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: neo4j
                      port:
                        number: 7474
          EOF
        ''}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Install required packages
    environment.systemPackages = with pkgs; [
      kubectl
      kubernetes-helm
    ];
  };
}