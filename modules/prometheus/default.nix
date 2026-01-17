{ charts, config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "prometheus";

  # https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack
  # Note: After first build, update chartHash with the actual hash from the build error
  chart = lib.helm.downloadHelmChart {
    repo = "https://prometheus-community.github.io/helm-charts";
    chart = "kube-prometheus-stack";
    version = "69.3.0";
    chartHash = "sha256-5e+TUar4z2BKOxcfOszRr1ujaApX8zCJ7b/tm/kebMM=";
  };

  defaultValues = cfg: {
    # Disable Grafana since we have a separate Grafana module
    grafana.enabled = false;

    # Prometheus configuration
    prometheus = {
      enabled = true;
      prometheusSpec = {
        # Run Prometheus on edgenix node
        nodeSelector = {
          "kubernetes.io/hostname" = "edgenix";
        };

        # Storage configuration
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "longhorn";
              accessModes = [ "ReadWriteOnce" ];
              resources = {
                requests = {
                  storage = "50Gi";
                };
              };
            };
          };
        };

        # Retention period
        retention = "30d";

        # Service monitor selector - scrape all ServiceMonitors
        serviceMonitorSelector = { };
        serviceMonitorSelectorNilUsesHelmValues = false;

        # Pod monitor selector - scrape all PodMonitors
        podMonitorSelector = { };
        podMonitorSelectorNilUsesHelmValues = false;

        # Additional scrape configs for node exporters on other hosts
        additionalScrapeConfigs = cfg.additionalScrapeConfigs or [];

        # Resource limits
        resources = {
          requests = {
            cpu = "500m";
            memory = "2Gi";
          };
          limits = {
            cpu = "2000m";
            memory = "4Gi";
          };
        };
      };
    };

    # Node Exporter - runs as DaemonSet on all nodes
    nodeExporter = {
      enabled = true;
      # Node exporter runs on all nodes, not just edgenix
    };

    # Alertmanager configuration
    alertmanager = {
      enabled = cfg.alertmanager.enabled or true;
      alertmanagerSpec = {
        # Run Alertmanager on edgenix node
        nodeSelector = {
          "kubernetes.io/hostname" = "edgenix";
        };

        # Storage configuration
        storage = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "longhorn";
              accessModes = [ "ReadWriteOnce" ];
              resources = {
                requests = {
                  storage = "10Gi";
                };
              };
            };
          };
        };

        # Resource limits
        resources = {
          requests = {
            cpu = "100m";
            memory = "128Mi";
          };
          limits = {
            cpu = "500m";
            memory = "512Mi";
          };
        };
      };
    };

    # Prometheus Operator
    prometheusOperator = {
      enabled = true;
      # Run operator on edgenix node
      nodeSelector = {
        "kubernetes.io/hostname" = "edgenix";
      };
    };

    # Kube-state-metrics
    kubeStateMetrics = {
      enabled = true;
    };

    # Default rules
    defaultRules = {
      create = true;
    };
  };

  extraOptions = {
    additionalScrapeConfigs = mkOption {
      description = mdDoc "Additional Prometheus scrape configurations";
      type = types.listOf types.attrs;
      default = [ ];
    };

    alertmanager = {
      enabled = mkOption {
        description = mdDoc "Enable Alertmanager";
        type = types.bool;
        default = true;
      };
    };
  };
}
