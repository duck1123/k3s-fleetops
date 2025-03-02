{ charts, config, lib, ... }:
let
  cfg = config.services.argo-workflows;

  chartConfig = {
    repo = "https://argoproj.github.io/argo-helm";
    chart = "argo-workflows";
    version = "0.45.10";
    chartHash = "sha256-xfLHmEshxwEUOPv1uUow8T55YNXpYCnd5QmMKY7fAJI=";
  };

  defaultNamespace = "argo-workflows";
  # domain = "specter-alice.dinsro.com";

  defaultValues = {
    controller = {
      extraEnv = [
        # https://argo-workflows.readthedocs.io/en/latest/executor_plugins/
        {
          name = "ARGO_EXECUTOR_PLUGINS";
          value = "true";
        }
      ];
      metricsConfig = {
        enabled = false;
        port = 9090;
        portName = "metrics";
      };

      persistence = {
        archive = true;
        postgresql = {
          host = "postgresql.postgresql";
          database = "argo_workflows";
          userNameSecret = {
            name = "postresql-password";
            namespace = "postgresql";
            key = "adminUsername";
          };
          passwordSecret = {
            name = "postresql-password";
            namespace = "postgresql";
            key = "adminPassword";
          };
        };
      };

      telemetryConfig.enabled = true;
      workflowNamespaces = [ "default" "argo-workflows" ];
    };

    server = {
      authModes = [ "client" ];

      ingress = {
        enabled = true;
        ingressClassName = "traefik";
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
          "ingress.kubernetes.io/force-ssl-redirect" = "true";
          "ingress.kubernetes.io/proxy-body-size" = "0";
          "ingress.kubernetes.io/ssl-redirect" = "true";
        };
        hosts = [ "argo-workflows.dev.kronkltd.net" ];
        tls = [{
          secretName = "argo-workflows-tls";
          hosts = [ "argo-workflows.dev.kronkltd.net" ];
        }];
      };

      workflow.serviceAccount.create = true;
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.argo-workflows = {
    enable = mkEnableOption "Enable application";
    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = defaultNamespace;
    };

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    applications.argo-workflows = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.argo-workflows = { inherit chart values; };
    };
  };
}
