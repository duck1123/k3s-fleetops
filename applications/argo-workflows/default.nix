{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "argo-workflows";

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "argo-workflows";
    version = "11.1.10";
    chartHash = "sha256-jcwHQUh9nkcsFzF+DI69XXkWnmyNL3QMlnVucAlYtsY=";
  };

  uses-ingress = true;

  defaultValues = cfg: {
    controller = {
      extraEnvVars = [{
        # https://argo-workflows.readthedocs.io/en/latest/executor_plugins/
        name = "ARGO_EXECUTOR_PLUGINS";
        value = "true";
      }];

      persistence.archive.enabled = true;

      # These are applied to the ingress?
      service.annotations = with cfg.ingress; {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };

      telemetry.enabled = true;
      # workflowNamespaces = [ "default" "argo-workflows" ];
    };

    ingress = with cfg.ingress; {
      enabled = true;
      hostname = domain;
      inherit ingressClassName;

      # These have no effect
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      tls = true;
    };
  };

  extraResources = cfg: {
    secrets."duck.service-account-token" = {
      metadata.annotations."kubernetes.io/service-account.name" = "duck";
      type = "kubernetes.io/service-account-token";
    };
  };
}
