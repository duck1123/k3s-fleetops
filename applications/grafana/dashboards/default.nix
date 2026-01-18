{ ... }:
let
  # Common field config for time series panels
  timeseriesFieldConfig = {
    color = {
      mode = "palette-classic";
    };
    custom = {
      axisCenteredZero = false;
      axisColorMode = "text";
      axisLabel = "";
      axisPlacement = "auto";
      barAlignment = 0;
      drawStyle = "line";
      fillOpacity = 10;
      gradientMode = "none";
      hideFrom = {
        tooltip = false;
        viz = false;
        legend = false;
      };
      lineInterpolation = "linear";
      lineWidth = 1;
      pointSize = 5;
      scaleDistribution = {
        type = "linear";
      };
      showPoints = "never";
      spanNulls = false;
      stacking = {
        group = "A";
        mode = "none";
      };
      thresholdsStyle = {
        mode = "off";
      };
    };
    mappings = [ ];
    thresholds = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
      ];
    };
  };

  # Helper function to create a time series panel
  mkTimeseriesPanel =
    {
      id,
      title,
      expr ? null,
      legendFormat ? null,
      unit ? "short",
      gridPos,
      thresholds ? null,
      overrides ? [ ],
      min ? null,
      max ? null,
      targets ? null,
    }:
    let
      defaultTargets =
        if expr != null && legendFormat != null then
          [
            {
              datasource = "Prometheus";
              expr = expr;
              legendFormat = legendFormat;
              refId = "A";
            }
          ]
        else
          [ ];
    in
    {
      inherit id title;
      datasource = "Prometheus";
      type = "timeseries";
      fieldConfig = {
        defaults =
          timeseriesFieldConfig
          // {
            inherit unit;
            thresholds = if thresholds != null then thresholds else timeseriesFieldConfig.thresholds;
          }
          // (if min != null then { inherit min; } else { })
          // (if max != null then { inherit max; } else { });
        overrides = overrides;
      };
      gridPos = gridPos;
      options = {
        legend = {
          calcs = [
            "mean"
            "max"
          ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          mode = "multi";
          sort = "none";
        };
      };
      targets = if targets != null then targets else defaultTargets;
    };

  # Helper function to create a stat panel
  mkStatPanel =
    {
      id,
      title,
      expr,
      unit ? "short",
      gridPos,
      thresholds ? null,
    }:
    {
      inherit id title;
      datasource = "Prometheus";
      type = "stat";
      pluginVersion = "12.3.1";
      fieldConfig = {
        defaults = {
          color = {
            mode = "thresholds";
          };
          mappings = [ ];
          thresholds =
            if thresholds != null then
              thresholds
            else
              {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                ];
              };
          inherit unit;
        };
        overrides = [ ];
      };
      gridPos = gridPos;
      options = {
        colorMode = "value";
        graphMode = "area";
        justifyMode = "auto";
        orientation = "auto";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        textMode = "auto";
      };
      targets = [
        {
          datasource = "Prometheus";
          expr = expr;
          refId = "A";
        }
      ];
    };

  # Common dashboard structure
  mkDashboard =
    {
      title,
      uid,
      tags ? [ ],
      panels,
      refresh ? "30s",
      timeFrom ? "now-6h",
      timeTo ? "now",
    }:
    {
      annotations = {
        list = [
          {
            builtIn = 1;
            datasource = "Prometheus";
            enable = true;
            hide = true;
            iconColor = "rgba(0, 211, 255, 1)";
            name = "Annotations & Alerts";
            type = "dashboard";
          }
        ];
      };
      editable = true;
      fiscalYearStartMonth = 0;
      graphTooltip = 0;
      id = null;
      links = [ ];
      liveNow = false;
      inherit panels refresh;
      schemaVersion = 38;
      style = "dark";
      inherit tags;
      templating = {
        list = [ ];
      };
      time = {
        from = timeFrom;
        to = timeTo;
      };
      timepicker = { };
      timezone = "";
      inherit title uid;
      version = 1;
      weekStart = "";
    };

  # System Performance Dashboard
  systemPerformanceDashboard = mkDashboard {
    title = "System Performance & NFS";
    uid = "system-performance-nfs";
    tags = [
      "system"
      "nfs"
      "performance"
    ];
    panels = [
      (mkTimeseriesPanel {
        id = 1;
        title = "CPU Usage by Node";
        expr = ''100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
        legendFormat = "{{instance}}";
        unit = "percent";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 0;
        };
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "green";
              value = null;
            }
            {
              color = "red";
              value = 80;
            }
          ];
        };
      })
      (mkTimeseriesPanel {
        id = 2;
        title = "Memory Usage by Node";
        expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
        legendFormat = "{{instance}}";
        unit = "percent";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 0;
        };
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "green";
              value = null;
            }
            {
              color = "red";
              value = 80;
            }
          ];
        };
      })
      (mkTimeseriesPanel {
        id = 3;
        title = "Load Average by Node";
        expr = "node_load1";
        legendFormat = "{{instance}}";
        unit = "short";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 8;
        };
      })
      (mkTimeseriesPanel {
        id = 4;
        title = "Disk I/O by Node";
        expr = ''rate(node_disk_io_time_seconds_total{device!="ram.*"}[5m])'';
        legendFormat = "{{instance}} - {{device}}";
        unit = "percent";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 8;
        };
      })
      (mkTimeseriesPanel {
        id = 5;
        title = "Network Traffic by Node";
        expr = ''rate(node_network_receive_bytes_total{device!="lo"}[5m])'';
        legendFormat = "{{instance}} - {{device}} (RX)";
        unit = "Bps";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 16;
        };
      })
      (mkTimeseriesPanel {
        id = 6;
        title = "Total Network Traffic to NFS Server";
        expr = ''sum(rate(node_network_receive_bytes_total{device!="lo"}[5m]))'';
        legendFormat = "Total RX";
        unit = "Bps";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 16;
        };
      })
      (mkTimeseriesPanel {
        id = 7;
        title = "NFS Operations Rate";
        expr = "rate(node_nfs_requests_total[5m])";
        legendFormat = "{{instance}}";
        unit = "ops";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 24;
        };
      })
      (mkTimeseriesPanel {
        id = 8;
        title = "NFS Connections";
        expr = "node_nfs_connections_total";
        legendFormat = "{{instance}}";
        unit = "short";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 24;
        };
      })
      (mkTimeseriesPanel {
        id = 9;
        title = "NFS Retransmissions";
        expr = "rate(node_nfs_rpc_retransmissions_total[5m])";
        legendFormat = "{{instance}}";
        unit = "ops";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 32;
        };
      })
    ];
  };

  # Kubernetes Cluster Dashboard
  kubernetesClusterDashboard = mkDashboard {
    title = "Kubernetes Cluster Overview";
    uid = "kubernetes-cluster";
    tags = [
      "kubernetes"
      "cluster"
    ];
    panels = [
      (mkStatPanel {
        id = 1;
        title = "Nodes";
        expr = "count(kube_node_info)";
        gridPos = {
          h = 4;
          w = 3;
          x = 0;
          y = 0;
        };
      })
      (mkStatPanel {
        id = 2;
        title = "Pods";
        expr = "count(kube_pod_info)";
        gridPos = {
          h = 4;
          w = 3;
          x = 3;
          y = 0;
        };
      })
      (mkStatPanel {
        id = 3;
        title = "Deployments";
        expr = "count(kube_deployment_spec_replicas)";
        gridPos = {
          h = 4;
          w = 3;
          x = 6;
          y = 0;
        };
      })
      (mkStatPanel {
        id = 4;
        title = "Pending Pods";
        expr = ''sum(kube_pod_status_phase{phase="Pending"})'';
        gridPos = {
          h = 4;
          w = 3;
          x = 9;
          y = 0;
        };
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "green";
              value = null;
            }
            {
              color = "red";
              value = 1;
            }
          ];
        };
      })
      (mkStatPanel {
        id = 5;
        title = "Failed Pods";
        expr = ''sum(kube_pod_status_phase{phase="Failed"})'';
        gridPos = {
          h = 4;
          w = 3;
          x = 12;
          y = 0;
        };
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "green";
              value = null;
            }
            {
              color = "red";
              value = 1;
            }
          ];
        };
      })
      (mkTimeseriesPanel {
        id = 6;
        title = "Node CPU Usage (%)";
        expr = ''100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
        legendFormat = "{{instance}}";
        unit = "percent";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 4;
        };
      })
      (mkTimeseriesPanel {
        id = 7;
        title = "Node Memory Usage (%)";
        expr = "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100";
        legendFormat = "{{instance}}";
        unit = "percent";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 4;
        };
      })
      (mkTimeseriesPanel {
        id = 8;
        title = "Node Network Traffic";
        unit = "Bps";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 12;
        };
        targets = [
          {
            datasource = "Prometheus";
            expr = ''rate(node_network_receive_bytes_total{device!="lo"}[5m])'';
            legendFormat = "{{instance}} - {{device}} (RX)";
            refId = "A";
          }
          {
            datasource = "Prometheus";
            expr = ''rate(node_network_transmit_bytes_total{device!="lo"}[5m])'';
            legendFormat = "{{instance}} - {{device}} (TX)";
            refId = "B";
          }
        ];
      })
      (mkTimeseriesPanel {
        id = 9;
        title = "Node Disk I/O";
        unit = "Bps";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 12;
        };
        targets = [
          {
            datasource = "Prometheus";
            expr = ''rate(node_disk_read_bytes_total{device!="ram.*"}[5m])'';
            legendFormat = "{{instance}} - {{device}} (Read)";
            refId = "A";
          }
          {
            datasource = "Prometheus";
            expr = ''rate(node_disk_written_bytes_total{device!="ram.*"}[5m])'';
            legendFormat = "{{instance}} - {{device}} (Write)";
            refId = "B";
          }
        ];
      })
      (mkTimeseriesPanel {
        id = 10;
        title = "CPU Usage by Namespace";
        expr = ''sum(rate(container_cpu_usage_seconds_total{container!="POD",container!=""}[5m])) by (namespace)'';
        legendFormat = "{{namespace}}";
        unit = "short";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 20;
        };
      })
      (mkTimeseriesPanel {
        id = 11;
        title = "Memory Usage by Namespace";
        expr = ''sum(container_memory_usage_bytes{container!="POD",container!=""}) by (namespace)'';
        legendFormat = "{{namespace}}";
        unit = "bytes";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 20;
        };
      })
      (mkTimeseriesPanel {
        id = 12;
        title = "Pod Restarts (last hour)";
        expr = "sum(rate(kube_pod_container_status_restarts_total[1h])) by (namespace, pod)";
        legendFormat = "{{namespace}}/{{pod}}";
        unit = "short";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 28;
        };
      })
      (mkTimeseriesPanel {
        id = 13;
        title = "Pod Status by Phase";
        expr = "sum(kube_pod_status_phase) by (phase)";
        legendFormat = "{{phase}}";
        unit = "short";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 28;
        };
      })
      (mkTimeseriesPanel {
        id = 14;
        title = "Cluster Memory Usage";
        expr = "(1 - (sum(node_memory_MemAvailable_bytes) / sum(node_memory_MemTotal_bytes))) * 100";
        legendFormat = "Cluster Memory Usage";
        unit = "percent";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 36;
        };
      })
      (mkTimeseriesPanel {
        id = 15;
        title = "Cluster CPU Usage";
        expr = ''100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
        legendFormat = "Cluster CPU Usage";
        unit = "percent";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 36;
        };
      })
    ];
  };
in
{
  inherit systemPerformanceDashboard kubernetesClusterDashboard;
  # Export helper functions for creating custom dashboards
  inherit mkDashboard mkTimeseriesPanel mkStatPanel;
}
