{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hive-logging;
in
{
  options.services.hive-logging = {
    enable = mkEnableOption "Starfleet OS Hive Logging Services";
    
    elasticsearchPort = mkOption {
      type = types.int;
      default = 9200;
      description = "Elasticsearch server port";
    };
    
    kibanaPort = mkOption {
      type = types.int;
      default = 5601;
      description = "Kibana server port";
    };
    
    filebeat = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Filebeat for log shipping";
    };
    
    retentionDays = mkOption {
      type = types.int;
      default = 30;
      description = "Log retention period in days";
    };
  };

  config = mkIf cfg.enable {
    # Elasticsearch for log storage
    services.elasticsearch = {
      enable = true;
      package = pkgs.elasticsearch;
      port = cfg.elasticsearchPort;
      
      extraConf = ''
        cluster.name: starfleet-logging
        node.name: ${config.networking.hostName}
        network.host: 0.0.0.0
        http.port: ${toString cfg.elasticsearchPort}
        discovery.type: single-node
        xpack.security.enabled: false
        path.data: /var/lib/elasticsearch
        path.logs: /var/log/elasticsearch
      '';
    };
    
    # Kibana for log visualization
    services.kibana = {
      enable = true;
      package = pkgs.kibana;
      port = cfg.kibanaPort;
      
      extraConf = ''
        server.name: ${config.networking.hostName}
        server.host: "0.0.0.0"
        elasticsearch.hosts: ["http://localhost:${toString cfg.elasticsearchPort}"]
        xpack.security.enabled: false
      '';
    };
    
    # Filebeat for log shipping
    services.filebeat = mkIf cfg.filebeat {
      enable = true;
      package = pkgs.filebeat;
      
      inputs = {
        journald = {
          id = "journald-input";
          type = "journald";
          paths = [
            "/var/log/journal"
          ];
        };
        
        log = {
          type = "log";
          paths = [
            "/var/log/*.log"
            "/var/log/messages"
            "/var/log/syslog"
          ];
        };
      };
      
      modules = {
        system = {
          enabled = true;
        };
        
        auditd = {
          enabled = true;
        };
      };
      
      outputs = {
        elasticsearch = {
          hosts = [ "http://localhost:${toString cfg.elasticsearchPort}" ];
          index = "starfleet-logs-%{+yyyy.MM.dd}";
        };
      };
    };
    
    # Logrotate for log rotation
    services.logrotate = {
      enable = true;
      
      settings = {
        "/var/log/*.log" = {
          rotate = cfg.retentionDays;
          frequency = "daily";
          missingok = true;
          notifempty = true;
          compress = true;
          postrotate = "systemctl kill -s USR1 rsyslogd.service";
        };
      };
    };
    
    # Rsyslog for system logging
    services.rsyslogd = {
      enable = true;
      
      extraConfig = ''
        # Log all kernel messages to kern.log
        kern.*                                                 /var/log/kern.log
        
        # Log anything (except mail) of level info or higher.
        # Don't log private authentication messages!
        *.info;authpriv.none;mail.none                        /var/log/messages
        
        # The authpriv file has restricted access.
        authpriv.*                                             /var/log/secure
        
        # Log all the mail messages in one place.
        mail.*                                                 /var/log/maillog
        
        # Log cron stuff
        cron.*                                                 /var/log/cron
        
        # Everybody gets emergency messages
        *.emerg                                                :omusrmsg:*
        
        # Save news errors of level crit and higher
        uucp,news.crit                                         /var/log/spooler
        
        # Save boot messages also to boot.log
        local7.*                                               /var/log/boot.log
        
        # Forward logs to Elasticsearch
        *.* @127.0.0.1:9200
      '';
    };
    
    # Auditd for security auditing
    security.audit = {
      enable = true;
      
      rules = [
        # Log all commands run by root
        "-a exit,always -F arch=b64 -F euid=0 -S execve -k rootcmd"
        
        # Log changes to user/group information
        "-w /etc/group -p wa -k identity"
        "-w /etc/passwd -p wa -k identity"
        "-w /etc/shadow -p wa -k identity"
        
        # Log changes to network configuration
        "-w /etc/hosts -p wa -k network_changes"
        "-w /etc/sysconfig/network -p wa -k network_changes"
        
        # Log changes to system date/time
        "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S clock_settime -k time-change"
        
        # Log changes to system locale
        "-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale"
        
        # Log changes to authentication mechanisms
        "-w /etc/pam.d/ -p wa -k auth_changes"
        "-w /etc/nsswitch.conf -p wa -k auth_changes"
        
        # Log changes to sudoers
        "-w /etc/sudoers -p wa -k actions"
        "-w /etc/sudoers.d/ -p wa -k actions"
      ];
    };
    
    # Logging tools
    environment.systemPackages = with pkgs; [
      elasticsearch
      kibana
      filebeat
      logrotate
      rsyslog
      
      # Helper scripts
      (writeScriptBin "logging-status" ''
        #!/bin/bash
        echo "Starfleet OS Hive Logging Status"
        echo "================================"
        
        echo "Elasticsearch: http://localhost:${toString cfg.elasticsearchPort}"
        systemctl status elasticsearch
        
        echo ""
        echo "Kibana: http://localhost:${toString cfg.kibanaPort}"
        systemctl status kibana
        
        echo ""
        echo "Filebeat:"
        systemctl status filebeat
        
        echo ""
        echo "Log Storage:"
        df -h /var/log
        
        echo ""
        echo "Recent Logs:"
        journalctl -n 10 --no-pager
      '')
      
      (writeScriptBin "log-search" ''
        #!/bin/bash
        if [ $# -eq 0 ]; then
          echo "Usage: log-search <search_term>"
          exit 1
        fi
        
        SEARCH_TERM="$*"
        
        echo "Searching logs for: $SEARCH_TERM"
        echo ""
        
        echo "Journal logs:"
        journalctl -g "$SEARCH_TERM" --no-pager | tail -n 20
        
        echo ""
        echo "System logs:"
        grep -i "$SEARCH_TERM" /var/log/messages /var/log/syslog 2>/dev/null | tail -n 20
        
        echo ""
        echo "For more results, use Kibana: http://localhost:${toString cfg.kibanaPort}"
      '')
    ];
  };
}