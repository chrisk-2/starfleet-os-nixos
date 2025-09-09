{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.sandbox-workloads;
in
{
  options.services.sandbox-workloads = {
    enable = mkEnableOption "Starfleet OS Sandbox Workloads";
    
    enableDocker = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Docker containers";
    };
    
    enablePodman = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Podman containers";
    };
    
    enableKvm = mkOption {
      type = types.bool;
      default = true;
      description = "Enable KVM virtualization";
    };
    
    enableLxc = mkOption {
      type = types.bool;
      default = true;
      description = "Enable LXC containers";
    };
    
    sandboxPath = mkOption {
      type = types.str;
      default = "/var/lib/sandbox";
      description = "Path to sandbox directory";
    };
  };

  config = mkIf cfg.enable {
    # Create sandbox directory
    systemd.tmpfiles.rules = [
      "d ${cfg.sandboxPath} 0755 root root -"
      "d ${cfg.sandboxPath}/docker 0755 root root -"
      "d ${cfg.sandboxPath}/podman 0755 root root -"
      "d ${cfg.sandboxPath}/kvm 0755 root root -"
      "d ${cfg.sandboxPath}/lxc 0755 root root -"
    ];
    
    # Docker configuration
    virtualisation.docker = mkIf cfg.enableDocker {
      enable = true;
      storageDriver = "overlay2";
      extraOptions = "--data-root=${cfg.sandboxPath}/docker";
    };
    
    # Podman configuration
    virtualisation.podman = mkIf cfg.enablePodman {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };
    
    # KVM configuration
    virtualisation.libvirtd = mkIf cfg.enableKvm {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull.fd ];
        };
      };
    };
    
    # LXC configuration
    virtualisation.lxc = mkIf cfg.enableLxc {
      enable = true;
      lxcfs.enable = true;
    };
    
    virtualisation.lxd = mkIf cfg.enableLxc {
      enable = true;
      recommendedSysctlSettings = true;
    };
    
    # Kubernetes (k3s) for container orchestration
    services.k3s = {
      enable = true;
      role = "server";
      extraFlags = "--data-dir=${cfg.sandboxPath}/k3s";
    };
    
    # Firewall configuration
    networking.firewall = {
      allowedTCPPorts = [
        22    # SSH
        2376  # Docker
        6443  # Kubernetes API
        8443  # LXD API
      ];
    };
    
    # Sandbox tools
    environment.systemPackages = with pkgs; [
      # Docker tools
      docker
      docker-compose
      
      # Podman tools
      podman
      podman-compose
      
      # KVM tools
      qemu_kvm
      libvirt
      virt-manager
      virt-viewer
      spice-gtk
      
      # LXC tools
      lxc
      lxd
      
      # Kubernetes tools
      kubectl
      kubernetes-helm
      k9s
      
      # Helper scripts
      (writeScriptBin "sandbox-status" ''
        #!/bin/bash
        echo "Starfleet OS Sandbox Workloads Status"
        echo "==================================="
        
        echo "Docker status:"
        if ${toString cfg.enableDocker}; then
          systemctl status docker
          echo ""
          echo "Docker containers:"
          docker ps -a
        else
          echo "Docker disabled"
        fi
        
        echo ""
        echo "Podman status:"
        if ${toString cfg.enablePodman}; then
          systemctl status podman
          echo ""
          echo "Podman containers:"
          podman ps -a
        else
          echo "Podman disabled"
        fi
        
        echo ""
        echo "KVM status:"
        if ${toString cfg.enableKvm}; then
          systemctl status libvirtd
          echo ""
          echo "Virtual machines:"
          virsh list --all
        else
          echo "KVM disabled"
        fi
        
        echo ""
        echo "LXC status:"
        if ${toString cfg.enableLxc}; then
          systemctl status lxc
          echo ""
          echo "LXC containers:"
          lxc list
        else
          echo "LXC disabled"
        fi
        
        echo ""
        echo "Kubernetes status:"
        systemctl status k3s
        echo ""
        echo "Kubernetes nodes:"
        kubectl get nodes
        echo ""
        echo "Kubernetes pods:"
        kubectl get pods --all-namespaces
      '')
      
      (writeScriptBin "sandbox-create-container" ''
        #!/bin/bash
        if [ $# -lt 2 ]; then
          echo "Usage: sandbox-create-container <engine> <name> [image]"
          echo "Example: sandbox-create-container docker test-container ubuntu:latest"
          exit 1
        fi
        
        ENGINE=$1
        NAME=$2
        IMAGE=''${3:-alpine:latest}
        
        case "$ENGINE" in
          "docker")
            if ${toString cfg.enableDocker}; then
              echo "Creating Docker container $NAME from image $IMAGE"
              docker run -d --name $NAME $IMAGE
            else
              echo "Docker is disabled"
              exit 1
            fi
            ;;
          "podman")
            if ${toString cfg.enablePodman}; then
              echo "Creating Podman container $NAME from image $IMAGE"
              podman run -d --name $NAME $IMAGE
            else
              echo "Podman is disabled"
              exit 1
            fi
            ;;
          "lxc")
            if ${toString cfg.enableLxc}; then
              echo "Creating LXC container $NAME"
              lxc launch images:alpine/edge $NAME
            else
              echo "LXC is disabled"
              exit 1
            fi
            ;;
          *)
            echo "Unsupported engine: $ENGINE"
            echo "Supported engines: docker, podman, lxc"
            exit 1
            ;;
        esac
        
        echo "Container $NAME created"
      '')
      
      (writeScriptBin "sandbox-create-vm" ''
        #!/bin/bash
        if [ $# -lt 1 ]; then
          echo "Usage: sandbox-create-vm <name> [memory] [vcpus] [disk]"
          echo "Example: sandbox-create-vm test-vm 2048 2 20G"
          exit 1
        fi
        
        NAME=$1
        MEMORY=''${2:-2048}
        VCPUS=''${3:-2}
        DISK=''${4:-20G}
        
        if ${toString cfg.enableKvm}; then
          echo "Creating KVM virtual machine $NAME"
          echo "Memory: $MEMORY MB"
          echo "vCPUs: $VCPUS"
          echo "Disk: $DISK"
          
          # Create disk image
          qemu-img create -f qcow2 ${cfg.sandboxPath}/kvm/$NAME.qcow2 $DISK
          
          # Create VM
          virt-install \
            --name $NAME \
            --memory $MEMORY \
            --vcpus $VCPUS \
            --disk ${cfg.sandboxPath}/kvm/$NAME.qcow2,format=qcow2 \
            --os-variant generic \
            --network default \
            --graphics spice \
            --import \
            --noautoconsole
        else
          echo "KVM is disabled"
          exit 1
        fi
        
        echo "Virtual machine $NAME created"
      '')
    ];
    
    # User configuration
    users.users.sandbox = {
      isNormalUser = true;
      description = "Sandbox Workloads User";
      extraGroups = [ "docker" "libvirtd" "lxd" "wheel" ];
    };
  };
}