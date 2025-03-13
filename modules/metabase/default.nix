{ config, lib, ... }:
let
  cfg = config.services.metabase;

  chart = lib.helm.downloadHelmChart {
    repo = "https://pmint93.github.io/helm-charts";
    chart = "metabase";
    version = "2.18.0";
    chartHash = "sha256-jrTqPX/fBMuu01Y9HJ100m1Tr7gEuaUecpt8jIJATL4=";
  };

  defaultNamespace = "metabase";
  domain = "metabase.dev.kronkltd.net";
  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    replicaCount = 1;
    monitoring.enabled = true;
    ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      enabled = true;
      hosts = [ domain ];
      tls = [{
        secretName = "metabase-tls";
        hosts = [ domain ];
      }];
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.metabase = {
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
    applications.metabase = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.metabase = { inherit chart values; };
      resources.apps.v1.Deployment.metabase.spec.template.spec.containers.metabase.ports.protocol = "TCP";
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
