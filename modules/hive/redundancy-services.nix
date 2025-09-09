{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.redundancy;
in
{
  options.services.redundancy = {
    enable = mkEnableOption "Starfleet OS Redundancy Services";
    
    highAvailability = mkOption {
      type = types.bool;
      default = true;
      description = "Enable high availability services";
    };
    
    loadBalancing = mkOption {
      type = types.bool;
      default = true;
      description = "Enable load balancing";
    };
    
    failover = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic failover";
    };
    
    virtualIp = mkOption {
      type = types.str;
      default = "192.168.1.200";
      description = "Virtual IP address for HA services";
    };
  };

  config = mkIf cfg.enable {
    # Keepalived for high availability
    services.keepalived = mkIf cfg.highAvailability {
      enable = true;
      
      vrrpInstances = {
        VI_1 = {
          interface = "eth0";
          state = "BACKUP";
          virtualRouterId = 51;
          priority = 100;
          virtualIps = [
            {
              addr = cfg.virtualIp;
              dev = "eth0";
            }
          ];
          
          authentication = {
            authType = "PASS";
            authPass = "starfleet";
          };
          
          trackScripts = [
            "chk_haproxy"
          ];
        };
      };
      
      extraConfig = ''
        vrrp_script chk_haproxy {
          script "${pkgs.bash}/bin/bash -c '${pkgs.procps}/bin/pidof haproxy'"
          interval 2
          weight 2
        }
      '';
    };
    
    # HAProxy for load balancing
    services.haproxy = mkIf cfg.loadBalancing {
      enable = true;
      
      config = ''
        global
          log /dev/log local0
          log /dev/log local1 notice
          chroot /var/lib/haproxy
          stats socket /run/haproxy/admin.sock mode 660 level admin
          stats timeout 30s
          user haproxy
          group haproxy
          daemon
          
          # Default SSL material locations
          ca-base /etc/ssl/certs
          crt-base /etc/ssl/private
          
          # Default ciphers to use on SSL-enabled listening sockets.
          ssl-default-bind-ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS
          ssl-default-bind-options no-sslv3
        
        defaults
          log global
          mode http
          option httplog
          option dontlognull
          timeout connect 5000
          timeout client  50000
          timeout server  50000
          errorfile 400 /etc/haproxy/errors/400.http
          errorfile 403 /etc/haproxy/errors/403.http
          errorfile 408 /etc/haproxy/errors/408.http
          errorfile 500 /etc/haproxy/errors/500.http
          errorfile 502 /etc/haproxy/errors/502.http
          errorfile 503 /etc/haproxy/errors/503.http
          errorfile 504 /etc/haproxy/errors/504.http
        
        frontend http-in
          bind *:80
          default_backend web-servers
        
        backend web-servers
          balance roundrobin
          server bridge uss-enterprise-bridge:80 check
          server drone-a borg-drone-alpha:80 check
          server drone-b borg-drone-beta:80 check backup
        
        frontend stats
          bind *:8080
          stats enable
          stats uri /stats
          stats refresh 10s
          stats auth admin:starfleet
      '';
    };
    
    # Corosync/Pacemaker for cluster management
    services.corosync = mkIf cfg.failover {
      enable = true;
      
      clusterName = "starfleet-cluster";
      
      nodelist = [
        {
          nodeid = 1;
          ring0_addr = "uss-enterprise-bridge";
        }
        {
          nodeid = 2;
          ring0_addr = "borg-drone-alpha";
        }
        {
          nodeid = 3;
          ring0_addr = "borg-drone-beta";
        }
      ];
      
      quorum = {
        provider = "corosync_votequorum";
        expected_votes = 3;
        two_node = 1;
      };
    };
    
    services.pacemaker = mkIf cfg.failover {
      enable = true;
    };
    
    # DRBD for disk replication
    boot.extraModulePackages = [ config.boot.kernelPackages.drbd ];
    boot.kernelModules = [ "drbd" ];
    
    environment.etc."drbd.d/global_common.conf" = {
      text = ''
        global {
          usage-count no;
        }
        
        common {
          protocol C;
          
          handlers {
            fence-peer "/usr/lib/drbd/crm-fence-peer.sh";
            after-resync-target "/usr/lib/drbd/crm-unfence-peer.sh";
          }
          
          startup {
            wfc-timeout 120;
            degr-wfc-timeout 120;
          }
          
          disk {
            on-io-error detach;
          }
          
          net {
            max-buffers 8000;
            max-epoch-size 8000;
            sndbuf-size 0;
            rcvbuf-size 0;
            cram-hmac-alg sha1;
            shared-secret "starfleet";
          }
        }
      '';
    };
    
    environment.etc."drbd.d/r0.res" = {
      text = ''
        resource r0 {
          device /dev/drbd0;
          disk /dev/sdb1;
          meta-disk internal;
          
          on borg-drone-alpha {
            node-id 0;
            address 192.168.1.101:7788;
          }
          
          on borg-drone-beta {
            node-id 1;
            address 192.168.1.102:7788;
          }
        }
      '';
    };
    
    # GlusterFS for distributed storage
    services.glusterfs = {
      enable = true;
      
      extraConfig = ''
        volume starfleet-data
          type replica 2
          transport tcp
          create-mode 0640
          directory-mode 0750
          auth.allow 192.168.1.*
          nfs.disable on
          performance.cache-size 1GB
          performance.io-thread-count 32
          performance.write-behind on
          server.allow-insecure on
          server.event-threads 8
          client.event-threads 8
          brick borg-drone-alpha:/var/lib/glusterfs/bricks/starfleet-data
          brick borg-drone-beta:/var/lib/glusterfs/bricks/starfleet-data
        end-volume
      '';
    };
    
    # Create GlusterFS brick directory
    systemd.tmpfiles.rules = [
      "d /var/lib/glusterfs/bricks/starfleet-data 0750 root root -"
    ];
    
    # Redundancy tools
    environment.systemPackages = with pkgs; [
      keepalived
      haproxy
      corosync
      pacemaker
      drbd
      glusterfs
      
      # Helper scripts
      (writeScriptBin "redundancy-status" ''
        #!/bin/bash
        echo "Starfleet OS Redundancy Services Status"
        echo "======================================"
        
        echo "High Availability:"
        systemctl status keepalived
        
        echo ""
        echo "Load Balancing:"
        systemctl status haproxy
        
        echo ""
        echo "Cluster Management:"
        systemctl status corosync
        systemctl status pacemaker
        
        echo ""
        echo "Storage Replication:"
        cat /proc/drbd
        
        echo ""
        echo "Distributed Storage:"
        gluster volume info
        
        echo ""
        echo "Virtual IP:"
        ip addr show | grep ${cfg.virtualIp}
      '')
      
      (writeScriptBin "failover-test" ''
        #!/bin/bash
        echo "Starfleet OS Failover Test"
        echo "=========================="
        
        echo "This will simulate a service failure to test failover."
        echo "Press Ctrl+C to cancel or Enter to continue..."
        read
        
        echo "Stopping HAProxy service..."
        systemctl stop haproxy
        
        echo "Monitoring failover..."
        watch -n 1 "ip addr show | grep ${cfg.virtualIp}"
      '')
    ];
  };
}