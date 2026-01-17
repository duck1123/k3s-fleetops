{ charts, config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "grafana";

  # https://artifacthub.io/packages/helm/grafana/grafana
  chart = charts.grafana.grafana;

  uses-ingress = true;

  defaultValues = cfg: {
    # Run Grafana on edgenix node
    nodeSelector = {
      "kubernetes.io/hostname" = "edgenix";
    };

    ingress = with cfg.ingress; {
      inherit ingressClassName;

      enabled = true;
      hosts = [ domain ];

      annotations = lib.optionalAttrs (clusterIssuer != "") {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
      };

      tls = [{
        secretName = "grafana-tls";
        hosts = [ domain ];
      }];
    };

    persistence = {
      enabled = true;
      storageClassName = "longhorn";
    };

    # Admin credentials
    adminUser = cfg.adminUser or "admin";
    adminPassword = cfg.adminPassword or "";

    # Configure datasources via provisioning
    datasources = {
      "datasources.yaml" = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://prometheus-kube-prometheus-prometheus.prometheus:9090";
            isDefault = true;
            editable = true;
          }
        ];
      };
    };

    # Configure dashboards
    dashboardProviders = {
      "dashboardproviders.yaml" = {
        apiVersion = 1;
        providers = [
          {
            name = "default";
            orgId = 1;
            folder = "";
            type = "file";
            disableDeletion = false;
            editable = true;
            options = {
              path = "/var/lib/grafana/dashboards/default";
            };
          }
        ];
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

    # Security settings for Tailscale proxy
    grafana.ini = {
      server = {
        domain = cfg.ingress.domain;
        root_url = "https://${cfg.ingress.domain}";
      };
      "auth.proxy" = {
        enabled = "true";
        header_name = "X-WebAuth-User";
        header_property = "username";
        auto_sign_up = "true";
        enable_login_token = "true";
      };
    };
  };

  extraOptions = {
    adminUser = mkOption {
      description = mdDoc "Grafana admin username";
      type = types.str;
      default = "admin";
    };

    adminPassword = mkOption {
      description = mdDoc "Grafana admin password";
      type = types.str;
      default = "";
    };
  };
}
