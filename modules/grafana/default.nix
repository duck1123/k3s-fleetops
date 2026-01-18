{ ageRecipients, charts, config, lib, pkgs, ... }:
with lib;
let grafana-secret = "grafana-admin";
in mkArgoApp { inherit config lib; } {
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

    # Admin credentials - use existing SOPS secret instead of creating one
    admin = {
      existingSecret = grafana-secret;
      userKey = "admin-user";
      passwordKey = "admin-password";
    };

    # Configure datasources via provisioning
    datasources = {
      "datasources.yaml" = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            uid = "prometheus";
            access = "proxy";
            url = "http://prometheus-kube-prometheus-prometheus.prometheus:9090";
            isDefault = true;
            editable = true;
            jsonData = {
              httpMethod = "POST";
            };
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

    # Provision dashboards
    dashboards = {
      "default" = {
        "system-performance-nfs" = {
          json = builtins.readFile ./dashboards/system-performance.json;
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

    # Security settings for Tailscale proxy
    grafana.ini = lib.recursiveUpdate {
      server = {
        domain = cfg.ingress.domain;
        root_url = "https://${cfg.ingress.domain}";
      };
    } (lib.optionalAttrs (cfg.enableProxyAuth or false) {
      # Enable proxy auth if using Tailscale proxy-to-grafana
      # This allows authentication via Tailscale identity headers
      "auth.proxy" = {
        enabled = "true";
        header_name = "X-WebAuth-User";
        header_property = "username";
        auto_sign_up = "true";
        enable_login_token = "true";
      };
    });
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

    enableProxyAuth = mkOption {
      description = mdDoc "Enable proxy authentication for Tailscale proxy-to-grafana. If enabled, authentication is handled via Tailscale identity headers. If disabled, use normal username/password login.";
      type = types.bool;
      default = false;
    };
  };

  extraResources = cfg: {
    sopsSecrets.${grafana-secret} = lib.createSecret {
      inherit ageRecipients lib pkgs;
      inherit (cfg) namespace;
      secretName = grafana-secret;
      values = {
        "admin-user" = cfg.adminUser or "admin";
        "admin-password" = cfg.adminPassword or "";
      };
    };
  };
}
