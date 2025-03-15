{ charts, config, lib, ... }:
let
  cfg = config.services.argo-workflows;

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "argo-workflows";
    version = "11.1.10";
    chartHash = "sha256-jcwHQUh9nkcsFzF+DI69XXkWnmyNL3QMlnVucAlYtsY=";
  };

  defaultNamespace = "argo-workflows";
  domain = "argo-workflows.dev.kronkltd.net";

  defaultValues = {
    controller = {
      extraEnvVars = [{
        # https://argo-workflows.readthedocs.io/en/latest/executor_plugins/
        name = "ARGO_EXECUTOR_PLUGINS";
        value = "true";
      }];

      persistence.archive.enabled = true;

      # These are applied to the ingress?
      service.annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };

      telemetry.enabled = true;
      # workflowNamespaces = [ "default" "argo-workflows" ];
    };

    ingress = {
      enabled = true;
      hostname = domain;
      ingressClassName = "traefik";
      # These have no effect
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      tls = true;
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
    applications.argo-workflows = {
      inherit namespace;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.argo-workflows = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
