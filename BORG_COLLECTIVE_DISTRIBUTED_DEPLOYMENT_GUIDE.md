# Borg Collective Distributed Systems Deployment Guide
# Starfleet OS Implementation

## Overview

This guide provides step-by-step instructions for deploying the Borg Collective with distributed systems integration. The deployment includes Proxmox VE for virtualization, Ceph for distributed storage, Kubernetes (K3s) for container orchestration, Consul for service discovery, and Home Assistant with MQTT for sensor integration.

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

## Prerequisites

### Hardware Requirements

| Node           | CPU Cores | RAM      | Primary Storage    | Secondary Storage   |
|----------------|-----------|----------|-------------------|---------------------|
| Queen Node     | 6+        | 16GB+    | 240GB+ SSD        | 80GB+ SSD           |
| Drone-A        | 4+        | 12GB+    | 120GB+ SSD        | 1TB+ HDD            |
| Drone-B        | 2+        | 3GB+     | 500GB+ HDD        | 1TB+ HDD            |
| Edge Node      | 4+        | 6GB+     | 500GB+ HDD        | 320GB+ HDD          |
| Edge-PI        | 4         | 1GB+     | 32GB+ SD Card     | -                   |

### Network Requirements

- Dedicated subnet for the Borg Collective (e.g., 10.42.0.0/24)
- Static IP addresses for all nodes
- Internet connectivity for package downloads
- Firewall rules allowing inter-node communication

## Deployment Steps

### 1. Prepare Installation Media

1. Clone the Starfleet OS repository:
   ```bash
   git clone https://github.com/chrisk-2/starfleet-os-nixos.git
   cd starfleet-os-nixos
   ```

2. Build the installation ISOs:
   ```bash
   chmod +x build-borg-collective-distributed.sh
   ./build-borg-collective-distributed.sh
   ```

3. Write the ISOs to USB drives:
   ```bash
   # For Queen Node
   dd if=build/borg-queen-distributed.iso of=/dev/sdX bs=4M status=progress
   
   # For Drone Nodes
   dd if=build/borg-drone-distributed.iso of=/dev/sdY bs=4M status=progress
   
   # For Edge-PI
   dd if=build/borg-edge-pi-distributed.iso of=/dev/sdZ bs=4M status=progress
   ```

### 2. Install Queen Node

1. Boot from the Queen Node USB drive
2. Follow the NixOS installation process:
   ```bash
   # Partition the disk
   parted /dev/sda -- mklabel gpt
   parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
   parted /dev/sda -- set 1 boot on
   parted /dev/sda -- mkpart primary 512MiB 100%
   
   # Format partitions
   mkfs.fat -F 32 -n boot /dev/sda1
   mkfs.ext4 -L nixos /dev/sda2
   
   # Mount partitions
   mount /dev/disk/by-label/nixos /mnt
   mkdir -p /mnt/boot
   mount /dev/disk/by-label/boot /mnt/boot
   
   # Generate configuration
   nixos-generate-config --root /mnt
   
   # Copy our configuration
   cp /etc/nixos/borg-queen-distributed.nix /mnt/etc/nixos/configuration.nix
   
   # Install NixOS
   nixos-install
   ```

3. After installation, reboot into the new system:
   ```bash
   reboot
   ```

### 3. Install Drone Nodes

1. Boot from the Drone Node USB drive
2. Follow the same installation process as the Queen Node, but use the drone configuration:
   ```bash
   # Copy our configuration (adjust for each drone)
   cp /etc/nixos/borg-drone-distributed.nix /mnt/etc/nixos/configuration.nix
   
   # Edit the configuration to set the correct drone ID and IP address
   vim /mnt/etc/nixos/configuration.nix
   ```

3. After installation, reboot into the new system:
   ```bash
   reboot
   ```

### 4. Install Edge-PI

1. Flash the Edge-PI image to an SD card:
   ```bash
   dd if=build/borg-edge-pi-distributed.iso of=/dev/mmcblk0 bs=4M status=progress
   ```

2. Insert the SD card into the Raspberry Pi and power it on

### 5. Configure Proxmox VE Cluster

1. On the Queen Node, initialize the Proxmox cluster:
   ```bash
   pvecm create borg-collective
   ```

2. On each Drone Node, join the cluster:
   ```bash
   pvecm add 10.42.0.1
   ```

3. Verify the cluster status:
   ```bash
   pvecm status
   ```

### 6. Configure Ceph Storage

1. On the Queen Node, initialize the Ceph cluster:
   ```bash
   ceph-deploy new borg-queen
   
   # Edit ceph.conf to add network settings
   echo "public_network = 10.42.0.0/24" >> ceph.conf
   echo "cluster_network = 10.42.1.0/24" >> ceph.conf
   
   # Deploy monitors
   ceph-deploy mon create-initial
   ```

2. Deploy Ceph managers:
   ```bash
   ceph-deploy mgr create borg-queen borg-drone-a
   ```

3. Prepare OSD disks on each node:
   ```bash
   # On Queen Node
   ceph-deploy osd create --data /dev/sdb borg-queen
   
   # On Drone-A
   ceph-deploy osd create --data /dev/sdb borg-drone-a
   
   # On Drone-B
   ceph-deploy osd create --data /dev/sdb borg-drone-b
   ```

4. Create storage pools:
   ```bash
   ceph osd pool create vms 128
   ceph osd pool application enable vms rbd
   rbd pool init vms
   
   ceph osd pool create cephfs_data 128
   ceph osd pool create cephfs_metadata 32
   ceph fs new borgfs cephfs_metadata cephfs_data
   ```

5. Configure Proxmox to use Ceph:
   ```bash
   # Add RBD storage to Proxmox
   pvesm add rbd ceph-vms --pool vms --krbd 1
   
   # Add CephFS to Proxmox
   pvesm add cephfs ceph-fs --monhost 10.42.0.1,10.42.0.2,10.42.0.3 --path /
   ```

### 7. Configure Kubernetes Cluster

1. On the Queen Node, verify that K3s is running:
   ```bash
   systemctl status k3s
   ```

2. On each Drone Node, verify that K3s agent is running:
   ```bash
   systemctl status k3s-agent
   ```

3. On the Queen Node, check the cluster status:
   ```bash
   kubectl get nodes
   ```

4. Verify that the Ceph CSI is properly configured:
   ```bash
   kubectl get storageclass
   ```

### 8. Configure Consul Cluster

1. On the Queen Node, verify that Consul server is running:
   ```bash
   systemctl status consul
   ```

2. On each Drone Node, verify that Consul client is running:
   ```bash
   systemctl status consul
   ```

3. Check the Consul cluster status:
   ```bash
   consul members
   ```

4. Access the Consul UI at http://10.42.0.1:8500

### 9. Configure Home Assistant and MQTT

1. On the Edge-PI, verify that Home Assistant is running:
   ```bash
   systemctl status home-assistant
   ```

2. On the Queen Node, verify that the MQTT broker is running:
   ```bash
   systemctl status mosquitto
   ```

3. Access the Home Assistant UI at http://10.42.0.5:8123

4. Configure Home Assistant integrations:
   - Add MQTT integration
   - Add Borg Collective integration
   - Configure sensors and automations

### 10. Deploy Borg Collective Services

1. On the Queen Node, verify that the Borg Collective services are deployed in Kubernetes:
   ```bash
   kubectl get pods -n borg-collective
   ```

2. Access the Borg Collective API at http://10.42.0.1:8080

3. Access the LCARS API at http://lcars-api.borg-collective.local

4. Access Grafana at http://grafana.borg-collective.local (default credentials: admin/borg-collective)

## Verification

### 1. Verify Virtualization

1. Create a test VM on the Queen Node:
   ```bash
   qm create 100 --name test-vm --memory 1024 --net0 virtio,bridge=vmbr0
   qm start 100
   ```

2. Verify that the VM is running:
   ```bash
   qm list
   ```

### 2. Verify Storage

1. Create a test file on the CephFS mount:
   ```bash
   echo "Resistance is futile" > /collective/data/test.txt
   ```

2. Verify that the file is accessible from all nodes:
   ```bash
   cat /collective/data/test.txt
   ```

### 3. Verify Orchestration

1. Deploy a test pod in Kubernetes:
   ```bash
   kubectl run test-pod --image=nginx -n borg-collective
   ```

2. Verify that the pod is running:
   ```bash
   kubectl get pods -n borg-collective
   ```

### 4. Verify Service Discovery

1. Register a test service in Consul:
   ```bash
   consul services register -name=test-service -port=8080
   ```

2. Verify that the service is registered:
   ```bash
   consul catalog services
   ```

### 5. Verify Sensor Integration

1. Publish a test message to MQTT:
   ```bash
   mosquitto_pub -h 10.42.0.1 -p 1883 -u "borg-queen" -P "borg-queen-password" -t "borg/test" -m "Resistance is futile"
   ```

2. Verify that the message is received:
   ```bash
   mosquitto_sub -h 10.42.0.1 -p 1883 -u "borg-queen" -P "borg-queen-password" -t "borg/#" -v
   ```

## Troubleshooting

### Proxmox VE Issues

- **Cluster Join Failure**: Ensure that the nodes can communicate over ports 22, 3128, 5404, and 5405
- **VM Creation Failure**: Check storage availability and permissions

### Ceph Issues

- **OSD Not Starting**: Check disk permissions and ownership
- **Monitor Not Joining**: Verify network connectivity and firewall rules
- **Pool Creation Failure**: Check Ceph health status

### Kubernetes Issues

- **Node Not Joining**: Check K3s token and server address
- **Pod Scheduling Failure**: Check node resources and taints
- **Storage Provisioning Failure**: Verify Ceph CSI configuration

### Consul Issues

- **Client Not Joining**: Check server address and encryption key
- **Service Registration Failure**: Verify ACL permissions
- **DNS Resolution Failure**: Check DNS configuration

### Home Assistant Issues

- **MQTT Connection Failure**: Verify broker address and credentials
- **Sensor Data Not Updating**: Check MQTT topics and subscriptions
- **Automation Not Triggering**: Check trigger conditions and entity states

## Maintenance

### Backup Procedures

1. Back up Ceph configuration:
   ```bash
   cp -r /etc/ceph /backup/ceph
   ```

2. Back up Kubernetes resources:
   ```bash
   kubectl get all --all-namespaces -o yaml > /backup/kubernetes-resources.yaml
   ```

3. Back up Consul data:
   ```bash
   consul snapshot save /backup/consul-snapshot.snap
   ```

4. Back up Home Assistant configuration:
   ```bash
   cp -r /var/lib/hass /backup/homeassistant
   ```

### Upgrade Procedures

1. Upgrade NixOS:
   ```bash
   nixos-rebuild switch --upgrade
   ```

2. Upgrade Ceph:
   ```bash
   ceph orch upgrade start --image quay.io/ceph/ceph:v17.2.6
   ```

3. Upgrade K3s:
   ```bash
   k3s-upgrade
   ```

4. Upgrade Home Assistant:
   ```bash
   systemctl stop home-assistant
   pip install --upgrade homeassistant
   systemctl start home-assistant
   ```

## Conclusion

You have successfully deployed the Borg Collective with distributed systems integration. The system now provides:

1. **Resource Pooling**: Dynamically allocate CPU, RAM, and storage across the collective
2. **Self-Healing**: Automatic recovery from hardware or service failures
3. **Unified Storage**: Access the same data from any node in the collective
4. **Service Discovery**: Automatically find and connect to services across the collective
5. **Sensor Integration**: Incorporate environmental data into the collective consciousness

This implementation truly embodies the Borg philosophy: "We are the Borg. Your technological distinctiveness will be added to our own. Resistance is futile."