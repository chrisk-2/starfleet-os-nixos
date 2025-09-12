# Borg Collective Distributed Systems Implementation
# Starfleet OS Technical Implementation Plan

## Overview

This document outlines the technical implementation details for integrating distributed systems technologies (Proxmox VE, Kubernetes, Ceph, Consul, and Home Assistant) with the existing Starfleet OS Borg Collective architecture. This implementation will transform the Borg Collective from a collection of individual machines into a truly unified distributed system with shared resources, self-healing capabilities, and collective intelligence.

## Architecture Diagram

```
                    ┌─────────────────────────┐
                    │                         │
                    │  Unified Borg Collective │
                    │                         │
                    └─────────────┬───────────┘
                                  │
                 ┌───────────────┬┴┬───────────────┐
                 │               │ │               │
    ┌────────────┴──────────┐ ┌─┴─┴─────────────┐ ┌────────────┴──────────────┐
    │  Virtualization     │ │ Orchestration  │ │  Distributed      │
    │  (Proxmox VE)       │ │ (Kubernetes)   │ │  Storage (Ceph)   │
    └────────────┬────────┘ └───────┬─┬──────┘ └────────┬────────────┘
                 │                   │ │                 │
                 └───────────────────┘ └─────────────────┘
                           │                 │
                 ┌─────────┴─────────────┐      │
                 │                   │      │
    ┌────────────┴──────────┐ ┌─────────────┴───────────┐
    │  Service Discovery  │ │  Sensor Integration  │
    │  (Consul)           │ │  (Home Assistant)    │
    └──────────────────────┘ └──────────────────────────┘
```

## 1. NixOS Module Structure

We'll create the following NixOS modules to integrate the distributed systems with our Borg Collective:

```
modules/
├── borg/
│   ├── collective-manager.nix (existing)
│   ├── assimilation-system.nix (existing)
│   ├── collective-database.nix (existing)
│   ├── adaptation-system.nix (existing)
│   ├── virtualization/
│   │   ├── proxmox-integration.nix (new)
│   │   └── vm-templates.nix (new)
│   ├── storage/
│   │   ├── ceph-integration.nix (new)
│   │   └── distributed-storage.nix (new)
│   ├── orchestration/
│   │   ├── kubernetes-integration.nix (new)
│   │   └── container-services.nix (new)
│   ├── service-discovery/
│   │   ├── consul-integration.nix (new)
│   │   └── service-registry.nix (new)
│   └── sensor-integration/
│       ├── home-assistant-integration.nix (new)
│       └── mqtt-broker.nix (new)
```

## 2. Virtualization Layer: Proxmox VE Integration

### 2.1 proxmox-integration.nix

This module will provide the interface between NixOS and Proxmox VE, allowing the Borg Collective to manage virtual machines and containers.

```nix
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
      proxmox-ve
      pve-manager
      pve-container
      pve-firewall
      pve-ha-manager
      qemu-server
      ksm
      ceph
      ceph-common
      zfsutils
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
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = {
      virtualizationEnabled = true;
      virtualizationSystem = "proxmox";
      virtualizationEndpoint = "https://${cfg.nodeAddress}:8006/api2/json";
    };
  };
}
```

### 2.2 vm-templates.nix

This module will define VM templates for the Borg Collective to use when creating new virtual machines.

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.virtualization.templates;
in {
  options.services.borg.virtualization.templates = {
    enable = mkEnableOption "Borg Collective VM templates";
    
    templateDir = mkOption {
      type = types.path;
      default = "/var/lib/vz/template";
      description = "Directory for VM templates";
    };
    
    nixosTemplate = mkOption {
      type = types.bool;
      default = true;
      description = "Create NixOS VM template";
    };
    
    nixosIsoUrl = mkOption {
      type = types.str;
      default = "https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso";
      description = "URL to NixOS ISO for template";
    };
  };
  
  config = mkIf cfg.enable {
    # Install required packages
    environment.systemPackages = with pkgs; [
      wget
      qemu-utils
    ];
    
    # Create directory for templates
    systemd.tmpfiles.rules = [
      "d ${cfg.templateDir} 0755 root root -"
    ];
    
    # Create NixOS template
    systemd.services.create-nixos-template = mkIf cfg.nixosTemplate {
      description = "Create NixOS VM template";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      script = ''
        # Download NixOS ISO if not present
        ISO_FILE="${cfg.templateDir}/nixos.iso"
        if [ ! -f "$ISO_FILE" ]; then
          wget -O "$ISO_FILE" "${cfg.nixosIsoUrl}"
        fi
        
        # Create VM template if it doesn't exist
        if ! qm list | grep -q "9000"; then
          qm create 9000 --name nixos-template --memory 4096 --cores 2 --net0 virtio,bridge=vmbr0
          qm set 9000 --scsi0 local:32
          qm set 9000 --boot c --bootdisk scsi0
          qm set 9000 --ide2 local:iso/nixos.iso,media=cdrom
          qm set 9000 --serial0 socket --vga serial0
          qm template 9000
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = {
      vmTemplates = {
        nixos = {
          id = 9000;
          name = "nixos-template";
          description = "NixOS template for Borg Collective";
        };
      };
    };
  };
}
```

## 3. Distributed Storage: Ceph Integration

### 3.1 ceph-integration.nix

This module will integrate Ceph distributed storage with the Borg Collective.

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.storage.ceph;
in {
  options.services.borg.storage.ceph = {
    enable = mkEnableOption "Borg Collective Ceph integration";
    
    role = mkOption {
      type = types.enum [ "mon" "osd" "mgr" "mds" "client" ];
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
  };
  
  config = mkIf cfg.enable {
    # Install Ceph packages
    environment.systemPackages = with pkgs; [
      ceph
      ceph-common
    ];
    
    # Configure Ceph services based on role
    services.ceph = {
      enable = true;
      global = {
        fsid = "00000000-0000-0000-0000-000000000000"; # Will be generated during deployment
        monHost = concatStringsSep "," cfg.monitorNodes;
        public_network = cfg.publicNetwork;
        cluster_network = cfg.clusterNetwork;
      };
      
      mon = mkIf (cfg.role == "mon") {
        enable = true;
        daemons = [ config.networking.hostName ];
      };
      
      mgr = mkIf (cfg.role == "mgr") {
        enable = true;
        daemons = [ config.networking.hostName ];
      };
      
      osd = mkIf (cfg.role == "osd") {
        enable = true;
        daemons = map (dev: builtins.baseNameOf dev) cfg.osdDevices;
        extraConfig = {
          "osd max backfills" = "1";
          "osd recovery max active" = "1";
          "osd recovery op priority" = "1";
        };
      };
      
      mds = mkIf (cfg.role == "mds") {
        enable = true;
        daemons = [ config.networking.hostName ];
      };
      
      client = mkIf (cfg.role == "client") {
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
    ];
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = {
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
```

### 3.2 distributed-storage.nix

This module will provide a unified interface for distributed storage in the Borg Collective.

```nix
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
      example = {
        "/collective/data" = "cephfs:data";
        "/collective/vms" = "rbd:vms";
      };
    };
  };
  
  config = mkIf cfg.enable {
    # Enable appropriate storage backend
    services.borg.storage = {
      ceph.enable = cfg.type == "ceph";
    };
    
    # Configure mount points
    fileSystems = mapAttrs (mountPoint: source:
      let
        parts = splitString ":" source;
        storageType = elemAt parts 0;
        storageName = elemAt parts 1;
      in
      if storageType == "cephfs" then {
        device = "_netdev,name=admin,secret=${config.services.ceph.client.keyring}";
        fsType = "ceph";
        options = [
          "name=admin"
          "secretfile=/etc/ceph/admin.key"
          "mount=${storageName}"
        ];
      } else if storageType == "rbd" then {
        device = "/dev/rbd/${storageName}";
        fsType = "ext4";
        options = [ "defaults" "_netdev" ];
      } else {
        device = source;
        fsType = "nfs";
        options = [ "defaults" ];
      }
    ) cfg.mountPoints;
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = {
      distributedStorage = {
        enabled = true;
        type = cfg.type;
        mountPoints = cfg.mountPoints;
      };
    };
  };
}
```

## 4. Container Orchestration: Kubernetes Integration

### 4.1 kubernetes-integration.nix

This module will integrate Kubernetes (K3s) with the Borg Collective for container orchestration.

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.orchestration.kubernetes;
in {
  options.services.borg.orchestration.kubernetes = {
    enable = mkEnableOption "Borg Collective Kubernetes integration";
    
    role = mkOption {
      type = types.enum [ "master" "worker" ];
      default = "worker";
      description = "Role of this node in the Kubernetes cluster";
    };
    
    masterAddress = mkOption {
      type = types.str;
      default = "";
      description = "Address of the Kubernetes master node";
    };
    
    clusterToken = mkOption {
      type = types.str;
      default = "";
      description = "Token for joining the Kubernetes cluster";
    };
    
    storageClass = mkOption {
      type = types.str;
      default = "ceph-rbd";
      description = "Default storage class for Kubernetes";
    };
  };
  
  config = mkIf cfg.enable {
    # Install K3s
    services.k3s = {
      enable = true;
      role = cfg.role;
      serverAddr = cfg.role == "worker" ? "https://${cfg.masterAddress}:6443" : "";
      token = cfg.clusterToken;
      extraFlags = cfg.role == "master" ? [
        "--disable=traefik"
        "--disable=servicelb"
        "--flannel-backend=wireguard"
        "--cluster-cidr=10.42.0.0/16"
        "--service-cidr=10.43.0.0/16"
      ] : [];
    };
    
    # Configure firewall for Kubernetes
    networking.firewall.allowedTCPPorts = [
      6443  # Kubernetes API
      10250  # Kubelet
      2379  # etcd client
      2380  # etcd peer
      10251  # kube-scheduler
      10252  # kube-controller-manager
    ];
    
    # Configure Ceph CSI for Kubernetes storage
    systemd.services.ceph-csi-setup = mkIf (cfg.role == "master" && cfg.storageClass == "ceph-rbd") {
      description = "Setup Ceph CSI for Kubernetes";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" ];
      script = ''
        # Wait for Kubernetes API to be available
        until kubectl get nodes &>/dev/null; do
          echo "Waiting for Kubernetes API..."
          sleep 5
        done
        
        # Create namespace for Ceph CSI
        kubectl create namespace ceph-csi --dry-run=client -o yaml | kubectl apply -f -
        
        # Create Ceph secret
        kubectl -n ceph-csi create secret generic ceph-secret \
          --from-literal=userID=admin \
          --from-literal=userKey=$(ceph auth get-key client.admin) \
          --dry-run=client -o yaml | kubectl apply -f -
        
        # Apply Ceph CSI RBAC
        kubectl apply -f ${pkgs.writeText "csi-provisioner-rbac.yaml" ''
          # Content from https://raw.githubusercontent.com/ceph/ceph-csi/master/deploy/rbd/kubernetes/csi-provisioner-rbac.yaml
        ''}
        
        kubectl apply -f ${pkgs.writeText "csi-nodeplugin-rbac.yaml" ''
          # Content from https://raw.githubusercontent.com/ceph/ceph-csi/master/deploy/rbd/kubernetes/csi-nodeplugin-rbac.yaml
        ''}
        
        # Create storage class
        kubectl apply -f ${pkgs.writeText "ceph-rbd-sc.yaml" ''
          apiVersion: storage.k8s.io/v1
          kind: StorageClass
          metadata:
            name: ceph-rbd
          provisioner: rbd.csi.ceph.com
          parameters:
            clusterID: borg-collective
            pool: vms
            imageFeatures: layering
            csi.storage.k8s.io/provisioner-secret-name: ceph-secret
            csi.storage.k8s.io/provisioner-secret-namespace: ceph-csi
            csi.storage.k8s.io/controller-expand-secret-name: ceph-secret
            csi.storage.k8s.io/controller-expand-secret-namespace: ceph-csi
            csi.storage.k8s.io/node-stage-secret-name: ceph-secret
            csi.storage.k8s.io/node-stage-secret-namespace: ceph-csi
          reclaimPolicy: Delete
          allowVolumeExpansion: true
          mountOptions:
            - discard
        ''}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = {
      orchestrationEnabled = true;
      orchestrationSystem = "kubernetes";
      orchestrationEndpoint = cfg.role == "master" ? "https://localhost:6443" : "https://${cfg.masterAddress}:6443";
      kubeconfig = "/etc/rancher/k3s/k3s.yaml";
    };
  };
}
```

### 4.2 container-services.nix

This module will define container services to be deployed in the Kubernetes cluster.

```nix
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
  };
  
  config = mkIf cfg.enable {
    # Ensure Kubernetes is enabled
    services.borg.orchestration.kubernetes.enable = true;
    services.borg.orchestration.kubernetes.role = "master";
    
    # Deploy services
    systemd.services.deploy-borg-services = {
      description = "Deploy Borg Collective services to Kubernetes";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" "ceph-csi-setup.service" ];
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
          kubectl apply -f ${pkgs.writeText "lcars-api-deployment.yaml" ''
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
                    image: lcars-api:latest
                    ports:
                    - containerPort: 8080
                    env:
                    - name: CONSUL_HTTP_ADDR
                      value: "consul-server.${cfg.namespace}.svc.cluster.local:8500"
                    - name: MQTT_BROKER
                      value: "mosquitto.${cfg.namespace}.svc.cluster.local:1883"
          ''}
        ''}
        
        # Deploy Collective Manager
        ${optionalString cfg.collectiveManager ''
          kubectl apply -f ${pkgs.writeText "collective-manager-deployment.yaml" ''
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
                    image: collective-manager:latest
                    ports:
                    - containerPort: 8080
                    env:
                    - name: ROLE
                      value: "queen"
                    - name: CONSUL_HTTP_ADDR
                      value: "consul-server.${cfg.namespace}.svc.cluster.local:8500"
                    - name: MQTT_BROKER
                      value: "mosquitto.${cfg.namespace}.svc.cluster.local:1883"
          ''}
        ''}
        
        # Deploy Prometheus and Grafana
        ${optionalString cfg.monitoring ''
          kubectl apply -f ${pkgs.writeText "monitoring-deployment.yaml" ''
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
          ''}
        ''}
        
        # Deploy Neo4j
        ${optionalString cfg.neo4j ''
          kubectl apply -f ${pkgs.writeText "neo4j-deployment.yaml" ''
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
                    - containerPort: 7687
                    env:
                    - name: NEO4J_AUTH
                      value: "neo4j/borg-collective"
                    volumeMounts:
                    - name: neo4j-data
                      mountPath: /data
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
              storageClassName: ceph-rbd
          ''}
        ''}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
```

## 5. Service Discovery: Consul Integration

### 5.1 consul-integration.nix

This module will integrate Consul with the Borg Collective for service discovery.

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.discovery.consul;
in {
  options.services.borg.discovery.consul = {
    enable = mkEnableOption "Borg Collective Consul integration";
    
    role = mkOption {
      type = types.enum [ "server" "client" ];
      default = "client";
      description = "Role of this node in the Consul cluster";
    };
    
    datacenter = mkOption {
      type = types.str;
      default = "borg-collective";
      description = "Consul datacenter name";
    };
    
    serverNodes = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of Consul server node addresses";
    };
    
    nodeName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Name of this node in Consul";
    };
  };
  
  config = mkIf cfg.enable {
    # Install Consul
    services.consul = {
      enable = true;
      webUi = cfg.role == "server";
      extraConfig = {
        server = cfg.role == "server";
        bootstrap_expect = cfg.role == "server" ? 1 : null;
        datacenter = cfg.datacenter;
        data_dir = "/var/lib/consul";
        bind_addr = "0.0.0.0";
        client_addr = "0.0.0.0";
        node_name = cfg.nodeName;
        retry_join = cfg.serverNodes;
      };
    };
    
    # Configure firewall for Consul
    networking.firewall.allowedTCPPorts = [
      8300  # Server RPC
      8301  # Serf LAN
      8302  # Serf WAN
      8500  # HTTP API
      8600  # DNS
    ];
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = {
      discoveryEnabled = true;
      discoverySystem = "consul";
      discoveryEndpoint = "http://localhost:8500";
    };
  };
}
```

### 5.2 service-registry.nix

This module will provide a unified interface for service registration and discovery in the Borg Collective.

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.discovery.registry;
in {
  options.services.borg.discovery.registry = {
    enable = mkEnableOption "Borg Collective service registry";
    
    services = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Service name";
          };
          
          tags = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Service tags";
          };
          
          address = mkOption {
            type = types.str;
            description = "Service address";
          };
          
          port = mkOption {
            type = types.int;
            description = "Service port";
          };
          
          checks = mkOption {
            type = types.listOf (types.submodule {
              options = {
                type = mkOption {
                  type = types.enum [ "http" "tcp" "script" ];
                  description = "Check type";
                };
                
                target = mkOption {
                  type = types.str;
                  description = "Check target (URL, command, etc.)";
                };
                
                interval = mkOption {
                  type = types.str;
                  default = "30s";
                  description = "Check interval";
                };
              };
            });
            default = [];
            description = "Service health checks";
          };
        };
      });
      default = {};
      description = "Services to register";
    };
  };
  
  config = mkIf cfg.enable {
    # Ensure Consul is enabled
    services.borg.discovery.consul.enable = true;
    
    # Register services with Consul
    services.consul.extraConfig.services = mapAttrsToList (name: service: {
      inherit (service) name tags address port;
      checks = map (check: {
        ${check.type} = check.target;
        interval = check.interval;
      }) service.checks;
    }) cfg.services;
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = {
      registeredServices = cfg.services;
    };
  };
}
```

## 6. Sensor Integration: Home Assistant + MQTT

### 6.1 home-assistant-integration.nix

This module will integrate Home Assistant with the Borg Collective for sensor management.

```nix
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
  };
  
  config = mkIf cfg.enable {
    # Install Home Assistant if deployed locally
    services.home-assistant = mkIf (cfg.deployment == "local") {
      enable = true;
      openFirewall = true;
      config = {
        homeassistant = {
          name = "Borg Collective";
          latitude = "!secret latitude";
          longitude = "!secret longitude";
          elevation = 0;
          unit_system = "metric";
          time_zone = "UTC";
        };
        
        http = {
          server_port = 8123;
          use_x_forwarded_for = true;
          trusted_proxies = [ "127.0.0.1" "::1" ];
        };
        
        mqtt = {
          broker = "localhost";
          discovery = true;
          discovery_prefix = "homeassistant";
        };
        
        # Integration with Borg Collective
        rest = {
          - resource = "http://localhost:8080/api/collective/status";
            scan_interval = 30;
            sensor = {
              - name = "Borg Collective Status";
                value_template = "{{ value_json.status }}";
            };
        };
      };
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
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = {
      sensorIntegration = {
        enabled = true;
        type = "home-assistant";
        endpoint = cfg.url;
        token = cfg.token;
      };
    };
  };
}
```

### 6.2 mqtt-broker.nix

This module will set up an MQTT broker for sensor data communication in the Borg Collective.

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.sensors.mqtt;
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
    
    allowAnonymous = mkOption {
      type = types.bool;
      default = false;
      description = "Allow anonymous access to MQTT broker";
    };
    
    users = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          password = mkOption {
            type = types.str;
            description = "User password";
          };
          
          acl = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Access control list for user";
          };
        };
      });
      default = {};
      description = "MQTT users";
    };
  };
  
  config = mkIf cfg.enable {
    # Install Mosquitto MQTT broker for local deployment
    services.mosquitto = mkIf (cfg.deployment == "local") {
      enable = true;
      port = cfg.port;
      host = "0.0.0.0";
      allowAnonymous = cfg.allowAnonymous;
      users = mapAttrsToList (name: user: {
        inherit name;
        password = user.password;
        acl = user.acl;
      }) cfg.users;
      settings = {
        persistence = true;
        persistence_location = "/var/lib/mosquitto/";
        log_dest = "stderr";
      };
    };
    
    # Deploy Mosquitto in Kubernetes
    systemd.services.deploy-mqtt-broker = mkIf (cfg.deployment == "kubernetes") {
      description = "Deploy MQTT broker to Kubernetes";
      wantedBy = [ "multi-user.target" ];
      after = [ "k3s.service" ];
      script = ''
        # Wait for Kubernetes API to be available
        until kubectl get nodes &>/dev/null; do
          echo "Waiting for Kubernetes API..."
          sleep 5
        done
        
        # Create ConfigMap for Mosquitto configuration
        kubectl create configmap mosquitto-config -n borg-collective --from-literal=mosquitto.conf="
        listener ${toString cfg.port}
        allow_anonymous ${if cfg.allowAnonymous then "true" else "false"}
        password_file /mosquitto/config/passwd
        persistence true
        persistence_location /mosquitto/data/
        log_dest stderr
        " --dry-run=client -o yaml | kubectl apply -f -
        
        # Create Secret for Mosquitto password file
        kubectl create secret generic mosquitto-passwd -n borg-collective --from-literal=passwd="
        ${concatStringsSep "\n" (mapAttrsToList (name: user: "${name}:${user.password}") cfg.users)}
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
                volumeMounts:
                - name: mosquitto-config
                  mountPath: /mosquitto/config/mosquitto.conf
                  subPath: mosquitto.conf
                - name: mosquitto-passwd
                  mountPath: /mosquitto/config/passwd
                  subPath: passwd
                - name: mosquitto-data
                  mountPath: /mosquitto/data
              volumes:
              - name: mosquitto-config
                configMap:
                  name: mosquitto-config
              - name: mosquitto-passwd
                secret:
                  secretName: mosquitto-passwd
              - name: mosquitto-data
                persistentVolumeClaim:
                  claimName: mosquitto-data
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
          storageClassName: ceph-rbd
        EOF
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Configure firewall for MQTT
    networking.firewall.allowedTCPPorts = mkIf (cfg.deployment == "local") [
      cfg.port
    ];
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = {
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
```

## 7. LCARS Integration

### 7.1 Update to collective-manager.nix

We need to update the existing collective-manager.nix to integrate with the distributed systems:

```nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.borg.collective-manager;
in {
  options.services.borg.collective-manager = {
    # Existing options...
    
    # New options for distributed systems
    virtualizationEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable virtualization integration";
    };
    
    virtualizationSystem = mkOption {
      type = types.str;
      default = "proxmox";
      description = "Virtualization system to use";
    };
    
    virtualizationEndpoint = mkOption {
      type = types.str;
      default = "";
      description = "Endpoint for virtualization API";
    };
    
    storageEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable distributed storage integration";
    };
    
    storageSystem = mkOption {
      type = types.str;
      default = "ceph";
      description = "Storage system to use";
    };
    
    storagePools = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          type = mkOption {
            type = types.str;
            description = "Pool type";
          };
          
          size = mkOption {
            type = types.str;
            description = "Pool size";
          };
          
          replicas = mkOption {
            type = types.int;
            default = 2;
            description = "Number of replicas";
          };
        };
      });
      default = {};
      description = "Storage pools";
    };
    
    orchestrationEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable container orchestration integration";
    };
    
    orchestrationSystem = mkOption {
      type = types.str;
      default = "kubernetes";
      description = "Orchestration system to use";
    };
    
    orchestrationEndpoint = mkOption {
      type = types.str;
      default = "";
      description = "Endpoint for orchestration API";
    };
    
    kubeconfig = mkOption {
      type = types.str;
      default = "";
      description = "Path to kubeconfig file";
    };
    
    discoveryEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable service discovery integration";
    };
    
    discoverySystem = mkOption {
      type = types.str;
      default = "consul";
      description = "Service discovery system to use";
    };
    
    discoveryEndpoint = mkOption {
      type = types.str;
      default = "";
      description = "Endpoint for service discovery API";
    };
    
    registeredServices = mkOption {
      type = types.attrs;
      default = {};
      description = "Services registered with service discovery";
    };
    
    sensorIntegration = mkOption {
      type = types.submodule {
        options = {
          enabled = mkOption {
            type = types.bool;
            default = false;
            description = "Enable sensor integration";
          };
          
          type = mkOption {
            type = types.str;
            default = "home-assistant";
            description = "Sensor integration type";
          };
          
          endpoint = mkOption {
            type = types.str;
            default = "";
            description = "Endpoint for sensor integration API";
          };
          
          token = mkOption {
            type = types.str;
            default = "";
            description = "Authentication token for sensor integration";
          };
        };
      };
      default = {};
      description = "Sensor integration configuration";
    };
    
    mqttEnabled = mkOption {
      type = types.bool;
      default = false;
      description = "Enable MQTT integration";
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
    
    mqttTopics = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "MQTT topics to subscribe to";
    };
  };
  
  config = mkIf cfg.enable {
    # Existing configuration...
    
    # Update package with distributed systems support
    environment.systemPackages = with pkgs; [
      # Existing packages...
      
      # New packages for distributed systems
      (pkgs.borg-collective-manager.override {
        enableVirtualization = cfg.virtualizationEnabled;
        enableStorage = cfg.storageEnabled;
        enableOrchestration = cfg.orchestrationEnabled;
        enableDiscovery = cfg.discoveryEnabled;
        enableSensors = cfg.sensorIntegration.enabled;
        enableMqtt = cfg.mqttEnabled;
      })
    ];
    
    # Update service configuration
    systemd.services.borg-collective-manager = {
      # Existing configuration...
      
      # Update environment variables for distributed systems
      environment = {
        # Existing environment...
        
        # Virtualization
        VIRTUALIZATION_ENABLED = toString cfg.virtualizationEnabled;
        VIRTUALIZATION_SYSTEM = cfg.virtualizationSystem;
        VIRTUALIZATION_ENDPOINT = cfg.virtualizationEndpoint;
        
        # Storage
        STORAGE_ENABLED = toString cfg.storageEnabled;
        STORAGE_SYSTEM = cfg.storageSystem;
        STORAGE_POOLS = builtins.toJSON cfg.storagePools;
        
        # Orchestration
        ORCHESTRATION_ENABLED = toString cfg.orchestrationEnabled;
        ORCHESTRATION_SYSTEM = cfg.orchestrationSystem;
        ORCHESTRATION_ENDPOINT = cfg.orchestrationEndpoint;
        KUBECONFIG = cfg.kubeconfig;
        
        # Discovery
        DISCOVERY_ENABLED = toString cfg.discoveryEnabled;
        DISCOVERY_SYSTEM = cfg.discoverySystem;
        DISCOVERY_ENDPOINT = cfg.discoveryEndpoint;
        REGISTERED_SERVICES = builtins.toJSON cfg.registeredServices;
        
        # Sensors
        SENSOR_INTEGRATION_ENABLED = toString cfg.sensorIntegration.enabled;
        SENSOR_INTEGRATION_TYPE = cfg.sensorIntegration.type;
        SENSOR_INTEGRATION_ENDPOINT = cfg.sensorIntegration.endpoint;
        SENSOR_INTEGRATION_TOKEN = cfg.sensorIntegration.token;
        
        # MQTT
        MQTT_ENABLED = toString cfg.mqttEnabled;
        MQTT_BROKER = cfg.mqttBroker;
        MQTT_PORT = toString cfg.mqttPort;
        MQTT_TOPICS = concatStringsSep "," cfg.mqttTopics;
      };
    };
  };
}
```

## 8. Configuration Templates

### 8.1 Queen Node Configuration

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/borg/collective-manager.nix
    ../modules/borg/assimilation-system.nix
    ../modules/borg/collective-database.nix
    ../modules/borg/adaptation-system.nix
    ../modules/borg/virtualization/proxmox-integration.nix
    ../modules/borg/virtualization/vm-templates.nix
    ../modules/borg/storage/ceph-integration.nix
    ../modules/borg/storage/distributed-storage.nix
    ../modules/borg/orchestration/kubernetes-integration.nix
    ../modules/borg/orchestration/container-services.nix
    ../modules/borg/service-discovery/consul-integration.nix
    ../modules/borg/service-discovery/service-registry.nix
    ../modules/borg/sensor-integration/home-assistant-integration.nix
    ../modules/borg/sensor-integration/mqtt-broker.nix
  ];

  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "borg-queen";
  networking.networkmanager.enable = true;

  # Enable Borg Collective Manager
  services.borg.collective-manager = {
    enable = true;
    role = "queen";
    drones = [
      { id = "drone-a"; address = "10.42.0.2"; }
      { id = "drone-b"; address = "10.42.0.3"; }
      { id = "edge-node"; address = "10.42.0.4"; }
      { id = "edge-pi"; address = "10.42.0.5"; }
    ];
  };

  # Enable Borg Assimilation System
  services.borg.assimilation-system = {
    enable = true;
    role = "queen";
    targetNetworks = [
      "10.42.0.0/24"
      "192.168.1.0/24"
    ];
  };

  # Enable Borg Collective Database
  services.borg.collective-database = {
    enable = true;
    role = "primary";
    replicaNodes = [
      "10.42.0.2"
      "10.42.0.3"
    ];
  };

  # Enable Borg Adaptation System
  services.borg.adaptation-system = {
    enable = true;
    role = "central";
    adaptationRules = [
      { name = "network-failure"; action = "reroute"; }
      { name = "storage-failure"; action = "redistribute"; }
      { name = "node-failure"; action = "reassign"; }
    ];
  };

  # Enable Proxmox VE integration
  services.borg.virtualization.proxmox = {
    enable = true;
    role = "server";
    nodeAddress = "10.42.0.1";
  };

  # Enable VM templates
  services.borg.virtualization.templates = {
    enable = true;
    nixosTemplate = true;
  };

  # Enable Ceph integration
  services.borg.storage.ceph = {
    enable = true;
    role = "mon";
    monitorNodes = [ "10.42.0.1" "10.42.0.2" "10.42.0.3" ];
    osdDevices = [ "/dev/sdb" ];
  };

  # Enable distributed storage
  services.borg.storage.distributed = {
    enable = true;
    type = "ceph";
    mountPoints = {
      "/collective/data" = "cephfs:data";
      "/collective/vms" = "rbd:vms";
    };
  };

  # Enable Kubernetes integration
  services.borg.orchestration.kubernetes = {
    enable = true;
    role = "master";
    clusterToken = "borg-collective-token";
  };

  # Enable container services
  services.borg.orchestration.services = {
    enable = true;
    lcarsApi = true;
    collectiveManager = true;
    monitoring = true;
    neo4j = true;
  };

  # Enable Consul integration
  services.borg.discovery.consul = {
    enable = true;
    role = "server";
    nodeName = "borg-queen";
  };

  # Enable service registry
  services.borg.discovery.registry = {
    enable = true;
    services = {
      "collective-api" = {
        name = "collective-api";
        tags = [ "api" "borg" ];
        address = "10.42.0.1";
        port = 8080;
        checks = [
          {
            type = "http";
            target = "http://localhost:8080/health";
            interval = "30s";
          }
        ];
      };
    };
  };

  # Enable Home Assistant integration
  services.borg.sensors.homeAssistant = {
    enable = true;
    deployment = "remote";
    url = "http://10.42.0.5:8123";
    token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...";
  };

  # Enable MQTT broker
  services.borg.sensors.mqtt = {
    enable = true;
    deployment = "local";
    allowAnonymous = false;
    users = {
      "borg-queen" = {
        password = "borg-queen-password";
        acl = [ "readwrite #" ];
      };
      "borg-drone" = {
        password = "borg-drone-password";
        acl = [ "read #" "write sensors/#" ];
      };
      "edge-pi" = {
        password = "edge-pi-password";
        acl = [ "read #" "write sensors/edge-pi/#" ];
      };
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
    tmux
    curl
    jq
  ];

  # Enable SSH
  services.openssh.enable = true;

  # User configuration
  users.users.borg = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "borg";
  };

  # System settings
  system.stateVersion = "24.05";
}
```

### 8.2 Drone Node Configuration

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/borg/collective-manager.nix
    ../modules/borg/assimilation-system.nix
    ../modules/borg/collective-database.nix
    ../modules/borg/adaptation-system.nix
    ../modules/borg/virtualization/proxmox-integration.nix
    ../modules/borg/storage/ceph-integration.nix
    ../modules/borg/storage/distributed-storage.nix
    ../modules/borg/orchestration/kubernetes-integration.nix
    ../modules/borg/service-discovery/consul-integration.nix
    ../modules/borg/service-discovery/service-registry.nix
    ../modules/borg/sensor-integration/mqtt-broker.nix
  ];

  # Basic system configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "borg-drone-a";  # Change for each drone
  networking.networkmanager.enable = true;

  # Enable Borg Collective Manager
  services.borg.collective-manager = {
    enable = true;
    role = "drone";
    queenAddress = "10.42.0.1";
  };

  # Enable Borg Assimilation System
  services.borg.assimilation-system = {
    enable = true;
    role = "drone";
    queenAddress = "10.42.0.1";
  };

  # Enable Borg Collective Database
  services.borg.collective-database = {
    enable = true;
    role = "replica";
    primaryNode = "10.42.0.1";
  };

  # Enable Borg Adaptation System
  services.borg.adaptation-system = {
    enable = true;
    role = "node";
    centralNode = "10.42.0.1";
  };

  # Enable Proxmox VE integration
  services.borg.virtualization.proxmox = {
    enable = true;
    role = "client";
    nodeAddress = "10.42.0.2";  # Change for each drone
    serverNodes = [ "10.42.0.1" ];
  };

  # Enable Ceph integration
  services.borg.storage.ceph = {
    enable = true;
    role = "osd";
    monitorNodes = [ "10.42.0.1" "10.42.0.2" "10.42.0.3" ];
    osdDevices = [ "/dev/sdb" ];  # Change for each drone
  };

  # Enable distributed storage
  services.borg.storage.distributed = {
    enable = true;
    type = "ceph";
    mountPoints = {
      "/collective/data" = "cephfs:data";
    };
  };

  # Enable Kubernetes integration
  services.borg.orchestration.kubernetes = {
    enable = true;
    role = "worker";
    masterAddress = "10.42.0.1";
    clusterToken = "borg-collective-token";
  };

  # Enable Consul integration
  services.borg.discovery.consul = {
    enable = true;
    role = "client";
    nodeName = "borg-drone-a";  # Change for each drone
    serverNodes = [ "10.42.0.1" ];
  };

  # Enable service registry
  services.borg.discovery.registry = {
    enable = true;
    services = {
      "drone-service" = {
        name = "drone-service";
        tags = [ "drone" "borg" ];
        address = "10.42.0.2";  # Change for each drone
        port = 8080;
        checks = [
          {
            type = "http";
            target = "http://localhost:8080/health";
            interval = "30s";
          }
        ];
      };
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
    tmux
    curl
    jq
  ];

  # Enable SSH
  services.openssh.enable = true;

  # User configuration
  users.users.borg = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "borg";
  };

  # System settings
  system.stateVersion = "24.05";
}
```

### 8.3 Edge-PI Configuration

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/borg/collective-manager.nix
    ../modules/borg/assimilation-system.nix
    ../modules/borg/adaptation-system.nix
    ../modules/borg/service-discovery/consul-integration.nix
    ../modules/borg/service-discovery/service-registry.nix
    ../modules/borg/sensor-integration/home-assistant-integration.nix
    ../modules/borg/sensor-integration/mqtt-broker.nix
  ];

  # Basic system configuration
  boot.loader.raspberryPi = {
    enable = true;
    version = 3;
  };
  networking.hostName = "edge-pi";
  networking.networkmanager.enable = true;

  # Enable Borg Collective Manager
  services.borg.collective-manager = {
    enable = true;
    role = "edge";
    queenAddress = "10.42.0.1";
  };

  # Enable Borg Assimilation System
  services.borg.assimilation-system = {
    enable = true;
    role = "edge";
    queenAddress = "10.42.0.1";
  };

  # Enable Borg Adaptation System
  services.borg.adaptation-system = {
    enable = true;
    role = "edge";
    centralNode = "10.42.0.1";
  };

  # Enable Consul integration
  services.borg.discovery.consul = {
    enable = true;
    role = "client";
    nodeName = "edge-pi";
    serverNodes = [ "10.42.0.1" ];
  };

  # Enable service registry
  services.borg.discovery.registry = {
    enable = true;
    services = {
      "edge-pi-sensor" = {
        name = "edge-pi-sensor";
        tags = [ "sensor" "edge" ];
        address = "10.42.0.5";
        port = 8080;
        checks = [
          {
            type = "http";
            target = "http://localhost:8080/health";
            interval = "30s";
          }
        ];
      };
    };
  };

  # Enable Home Assistant
  services.borg.sensors.homeAssistant = {
    enable = true;
    deployment = "local";
  };

  # Enable MQTT client
  services.borg.sensors.mqtt = {
    enable = true;
    deployment = "local";
    allowAnonymous = false;
    users = {
      "edge-pi" = {
        password = "edge-pi-password";
        acl = [ "readwrite sensors/edge-pi/#" "read #" ];
      };
    };
  };

  # Enable GPIO for sensors
  hardware.gpio.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
    tmux
    curl
    jq
    python3
    python3Packages.pip
    python3Packages.gpiozero
  ];

  # Enable SSH
  services.openssh.enable = true;

  # User configuration
  users.users.borg = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "gpio" ];
    initialPassword = "borg";
  };

  # System settings
  system.stateVersion = "24.05";
}
```

## 9. Implementation Plan

### Phase 1: Module Development
1. Create the directory structure for the new modules
2. Implement the virtualization modules (proxmox-integration.nix, vm-templates.nix)
3. Implement the storage modules (ceph-integration.nix, distributed-storage.nix)
4. Implement the orchestration modules (kubernetes-integration.nix, container-services.nix)
5. Implement the service discovery modules (consul-integration.nix, service-registry.nix)
6. Implement the sensor integration modules (home-assistant-integration.nix, mqtt-broker.nix)
7. Update the collective-manager.nix module with distributed systems support

### Phase 2: Configuration Templates
1. Create the Queen Node configuration template
2. Create the Drone Node configuration template
3. Create the Edge-PI configuration template

### Phase 3: Testing
1. Test the modules individually
2. Test the integration between modules
3. Test the complete system

### Phase 4: Documentation
1. Update the implementation plan
2. Create a deployment guide
3. Create a troubleshooting guide

## 10. Conclusion

This implementation plan provides a comprehensive approach to integrating distributed systems technologies with the Starfleet OS Borg Collective. By leveraging Proxmox VE, Kubernetes, Ceph, Consul, and Home Assistant with MQTT, we create a resilient, self-healing collective consciousness that transcends the limitations of individual hardware components.

The resulting system will provide:
1. Resource Pooling: Dynamically allocate CPU, RAM, and storage across the collective
2. Self-Healing: Automatic recovery from hardware or service failures
3. Unified Storage: Access the same data from any node in the collective
4. Service Discovery: Automatically find and connect to services across the collective
5. Sensor Integration: Incorporate environmental data into the collective consciousness

This implementation truly embodies the Borg philosophy: "We are the Borg. Your technological distinctiveness will be added to our own. Resistance is futile."