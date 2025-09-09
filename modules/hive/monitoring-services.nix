{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hive-monitoring;
in
{
  options.services.hive-monitoring = {
    enable = mkEnableOption "Starfleet OS Hive Monitoring Services";
    
    prometheusPort = mkOption {
      type = types.int;
      default = 9090;
      description = "Prometheus server port";
    };
    
    grafanaPort = mkOption {
      type = types.int;
      default = 3000;
      description = "Grafana server port";
    };
    
    lokiPort = mkOption {
      type = types.int;
      default = 3100;
      description = "Loki server port";
    };
    
    retentionDays = mkOption {
      type = types.int;
      default = 15;
      description = "Data retention period in days";
    };
  };

  config = mkIf cfg.enable {
    # Prometheus monitoring
    services.prometheus = {
      enable = true;
      port = cfg.prometheusPort;
      
      retentionTime = "${toString cfg.retentionDays}d";
      
      globalConfig = {
        scrape_interval = "15s";
        evaluation_interval = "15s";
      };
      
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = [
                "uss-enterprise-bridge:9100"
                "borg-drone-alpha:9100"
                "borg-drone-beta:9100"
                "edge-sensor-drone:9100"
                "localhost:9100"
              ];
              labels = {
                group = "starfleet-nodes";
              };
            }
          ];
        }
      ];
      
      rules = [
        ''
          groups:
          - name: starfleet-alerts
            rules:
            - alert: NodeDown
              expr: up == 0
              for: 5m
              labels:
                severity: critical
              annotations:
                summary: "Node {{ $labels.instance }} down"
                description: "{{ $labels.instance }} has been down for more than 5 minutes."
            
            - alert: HighCpuLoad
              expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "High CPU load on {{ $labels.instance }}"
                description: "{{ $labels.instance }} has high CPU load (> 80%) for more than 5 minutes."
            
            - alert: HighMemoryUsage
              expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "High memory usage on {{ $labels.instance }}"
                description: "{{ $labels.instance }} has high memory usage (> 85%) for more than 5 minutes."
            
            - alert: LowDiskSpace
              expr: node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100 < 10
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "Low disk space on {{ $labels.instance }}"
                description: "{{ $labels.instance }} has less than 10% free disk space."
        ''
      ];
    };
    
    # Node exporter for system metrics
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [
        "cpu"
        "diskstats"
        "filesystem"
        "loadavg"
        "meminfo"
        "netdev"
        "stat"
        "time"
        "vmstat"
        "systemd"
      ];
    };
    
    # Grafana for visualization
    services.grafana = {
      enable = true;
      port = cfg.grafanaPort;
      
      provision = {
        enable = true;
        
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:${toString cfg.prometheusPort}";
            isDefault = true;
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            url = "http://localhost:${toString cfg.lokiPort}";
          }
        ];
        
        dashboards.settings.providers = [
          {
            name = "Starfleet Dashboards";
            options.path = "/etc/starfleet/dashboards";
          }
        ];
      };
    };
    
    # Loki for log aggregation
    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        
        server = {
          http_listen_port = cfg.lokiPort;
        };
        
        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore = {
                store = "inmemory";
              };
              replication_factor = 1;
            };
            final_sleep = "0s";
          };
          chunk_idle_period = "5m";
          chunk_retain_period = "30s";
        };
        
        schema_config = {
          configs = [
            {
              from = "2020-05-15";
              store = "boltdb";
              object_store = "filesystem";
              schema = "v11";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };
        
        storage_config = {
          boltdb = {
            directory = "/var/lib/loki/index";
          };
          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
        };
        
        limits_config = {
          enforce_metric_name = false;
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };
      };
    };
    
    # Promtail for log collection
    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };
        
        positions = {
          filename = "/tmp/positions.yaml";
        };
        
        clients = [
          {
            url = "http://localhost:${toString cfg.lokiPort}/loki/api/v1/push";
          }
        ];
        
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = "localhost";
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };
    
    # Create dashboard directory
    systemd.tmpfiles.rules = [
      "d /etc/starfleet/dashboards 0755 grafana grafana -"
    ];
    
    # Create default dashboard
    environment.etc."starfleet/dashboards/node-metrics.json" = {
      text = builtins.toJSON {
        annotations = {
          list = [
            {
              builtIn = 1;
              datasource = "-- Grafana --";
              enable = true;
              hide = true;
              iconColor = "rgba(0, 211, 255, 1)";
              name = "Annotations & Alerts";
              type = "dashboard";
            }
          ];
        };
        editable = true;
        gnetId = null;
        graphTooltip = 0;
        id = 1;
        links = [];
        panels = [
          {
            aliasColors = {};
            bars = false;
            dashLength = 10;
            dashes = false;
            datasource = "Prometheus";
            fill = 1;
            fillGradient = 0;
            gridPos = {
              h = 8;
              w = 12;
              x = 0;
              y = 0;
            };
            hiddenSeries = false;
            id = 2;
            legend = {
              avg = false;
              current = false;
              max = false;
              min = false;
              show = true;
              total = false;
              values = false;
            };
            lines = true;
            linewidth = 1;
            nullPointMode = "null";
            options = {
              dataLinks = [];
            };
            percentage = false;
            pointradius = 2;
            points = false;
            renderer = "flot";
            seriesOverrides = [];
            spaceLength = 10;
            stack = false;
            steppedLine = false;
            targets = [
              {
                expr = "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=&quot;idle&quot;}[5m])) * 100)";
                legendFormat = "{{instance}}";
                refId = "A";
              }
            ];
            thresholds = [];
            timeFrom = null;
            timeRegions = [];
            timeShift = null;
            title = "CPU Usage";
            tooltip = {
              shared = true;
              sort = 0;
              value_type = "individual";
            };
            type = "graph";
            xaxis = {
              buckets = null;
              mode = "time";
              name = null;
              show = true;
              values = [];
            };
            yaxes = [
              {
                format = "percent";
                label = null;
                logBase = 1;
                max = null;
                min = null;
                show = true;
              }
              {
                format = "short";
                label = null;
                logBase = 1;
                max = null;
                min = null;
                show = true;
              }
            ];
            yaxis = {
              align = false;
              alignLevel = null;
            };
          }
        ];
        schemaVersion = 22;
        style = "dark";
        tags = [];
        templating = {
          list = [];
        };
        time = {
          from = "now-6h";
          to = "now";
        };
        timepicker = {};
        timezone = "";
        title = "Node Metrics";
        uid = "node-metrics";
        version = 1;
      };
      mode = "0644";
      user = "grafana";
      group = "grafana";
    };
    
    # Monitoring tools
    environment.systemPackages = with pkgs; [
      prometheus
      prometheus-alertmanager
      grafana
      loki
      promtail
      
      # Helper scripts
      (writeScriptBin "hive-status" ''
        #!/bin/bash
        echo "Starfleet OS Hive Monitoring Status"
        echo "=================================="
        
        echo "Prometheus: http://localhost:${toString cfg.prometheusPort}"
        systemctl status prometheus
        
        echo ""
        echo "Grafana: http://localhost:${toString cfg.grafanaPort}"
        systemctl status grafana
        
        echo ""
        echo "Loki: http://localhost:${toString cfg.lokiPort}"
        systemctl status loki
        
        echo ""
        echo "Node Exporter: http://localhost:9100/metrics"
        systemctl status prometheus-node-exporter
      '')
    ];
  };
}