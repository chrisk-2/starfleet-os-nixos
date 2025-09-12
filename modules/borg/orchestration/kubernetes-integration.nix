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
    
    k3sVersion = mkOption {
      type = types.str;
      default = "latest";
      description = "Version of K3s to install";
    };
    
    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra flags to pass to K3s";
    };
    
    disableComponents = mkOption {
      type = types.listOf types.str;
      default = [ "traefik" "servicelb" ];
      description = "K3s components to disable";
    };
    
    clusterCidr = mkOption {
      type = types.str;
      default = "10.42.0.0/16";
      description = "CIDR for cluster network";
    };
    
    serviceCidr = mkOption {
      type = types.str;
      default = "10.43.0.0/16";
      description = "CIDR for service network";
    };
  };
  
  config = mkIf cfg.enable {
    # Install K3s
    services.k3s = {
      enable = true;
      role = cfg.role;
      serverAddr = cfg.role == "worker" ? "https://${cfg.masterAddress}:6443" : "";
      token = cfg.clusterToken;
      extraFlags = cfg.role == "master" ? 
        (map (component: "--disable=${component}") cfg.disableComponents) ++ [
          "--flannel-backend=wireguard"
          "--cluster-cidr=${cfg.clusterCidr}"
          "--service-cidr=${cfg.serviceCidr}"
        ] ++ cfg.extraFlags
        : cfg.extraFlags;
    };
    
    # Install kubectl and related tools
    environment.systemPackages = with pkgs; [
      kubectl
      kubernetes-helm
      k9s
      kubectx
      stern
      kustomize
    ];
    
    # Configure firewall for Kubernetes
    networking.firewall.allowedTCPPorts = [
      6443  # Kubernetes API
      10250  # Kubelet
      2379  # etcd client
      2380  # etcd peer
      10251  # kube-scheduler
      10252  # kube-controller-manager
      8472   # Flannel VXLAN
    ];
    
    networking.firewall.allowedUDPPorts = [
      8472   # Flannel VXLAN
      51820  # WireGuard
      51821  # WireGuard
    ];
    
    # Configure kubeconfig for root user
    environment.etc."kubernetes/admin.conf" = mkIf (cfg.role == "master") {
      source = "/etc/rancher/k3s/k3s.yaml";
    };
    
    # Configure Ceph CSI for Kubernetes storage
    systemd.services.ceph-csi-setup = mkIf (cfg.role == "master" && cfg.storageClass == "ceph-rbd" && config.services.borg.storage.ceph.enable) {
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
          apiVersion: v1
          kind: ServiceAccount
          metadata:
            name: rbd-csi-provisioner
            namespace: ceph-csi
          ---
          kind: ClusterRole
          apiVersion: rbac.authorization.k8s.io/v1
          metadata:
            name: rbd-external-provisioner-runner
          rules:
            - apiGroups: [""]
              resources: ["nodes"]
              verbs: ["get", "list", "watch"]
            - apiGroups: [""]
              resources: ["secrets"]
              verbs: ["get", "list", "watch"]
            - apiGroups: [""]
              resources: ["events"]
              verbs: ["list", "watch", "create", "update", "patch"]
            - apiGroups: [""]
              resources: ["persistentvolumes"]
              verbs: ["get", "list", "watch", "create", "update", "delete", "patch"]
            - apiGroups: [""]
              resources: ["persistentvolumeclaims"]
              verbs: ["get", "list", "watch", "update"]
            - apiGroups: ["storage.k8s.io"]
              resources: ["storageclasses"]
              verbs: ["get", "list", "watch"]
            - apiGroups: ["snapshot.storage.k8s.io"]
              resources: ["volumesnapshots"]
              verbs: ["get", "list"]
            - apiGroups: ["snapshot.storage.k8s.io"]
              resources: ["volumesnapshotcontents"]
              verbs: ["create", "get", "list", "watch", "update", "delete"]
            - apiGroups: ["snapshot.storage.k8s.io"]
              resources: ["volumesnapshotclasses"]
              verbs: ["get", "list", "watch"]
            - apiGroups: ["storage.k8s.io"]
              resources: ["volumeattachments"]
              verbs: ["get", "list", "watch", "update", "patch"]
            - apiGroups: ["storage.k8s.io"]
              resources: ["csinodes"]
              verbs: ["get", "list", "watch"]
            - apiGroups: [""]
              resources: ["persistentvolumeclaims/status"]
              verbs: ["update", "patch"]
          ---
          kind: ClusterRoleBinding
          apiVersion: rbac.authorization.k8s.io/v1
          metadata:
            name: rbd-csi-provisioner-role
          subjects:
            - kind: ServiceAccount
              name: rbd-csi-provisioner
              namespace: ceph-csi
          roleRef:
            kind: ClusterRole
            name: rbd-external-provisioner-runner
            apiGroup: rbac.authorization.k8s.io
        ''}
        
        kubectl apply -f ${pkgs.writeText "csi-nodeplugin-rbac.yaml" ''
          # Content from https://raw.githubusercontent.com/ceph/ceph-csi/master/deploy/rbd/kubernetes/csi-nodeplugin-rbac.yaml
          apiVersion: v1
          kind: ServiceAccount
          metadata:
            name: rbd-csi-nodeplugin
            namespace: ceph-csi
          ---
          kind: ClusterRole
          apiVersion: rbac.authorization.k8s.io/v1
          metadata:
            name: rbd-csi-nodeplugin
          rules:
            - apiGroups: [""]
              resources: ["nodes"]
              verbs: ["get"]
            - apiGroups: [""]
              resources: ["namespaces"]
              verbs: ["get", "list"]
            - apiGroups: [""]
              resources: ["persistentvolumes"]
              verbs: ["get", "list"]
            - apiGroups: ["storage.k8s.io"]
              resources: ["volumeattachments"]
              verbs: ["get", "list"]
          ---
          kind: ClusterRoleBinding
          apiVersion: rbac.authorization.k8s.io/v1
          metadata:
            name: rbd-csi-nodeplugin
          subjects:
            - kind: ServiceAccount
              name: rbd-csi-nodeplugin
              namespace: ceph-csi
          roleRef:
            kind: ClusterRole
            name: rbd-csi-nodeplugin
            apiGroup: rbac.authorization.k8s.io
        ''}
        
        # Create storage class
        kubectl apply -f ${pkgs.writeText "ceph-rbd-sc.yaml" ''
          apiVersion: storage.k8s.io/v1
          kind: StorageClass
          metadata:
            name: ceph-rbd
          provisioner: rbd.csi.ceph.com
          parameters:
            clusterID: ${config.services.borg.storage.ceph.fsid}
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
        
        # Set as default storage class
        kubectl patch storageclass ceph-rbd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    
    # Configure kubectl for users
    environment.variables = {
      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
    };
    
    # Integration with Borg Collective Manager
    services.borg.collective-manager = mkIf config.services.borg.collective-manager.enable {
      orchestrationEnabled = true;
      orchestrationSystem = "kubernetes";
      orchestrationEndpoint = cfg.role == "master" ? "https://localhost:6443" : "https://${cfg.masterAddress}:6443";
      kubeconfig = "/etc/rancher/k3s/k3s.yaml";
    };
  };
}