{ config, lib, pkgs, ... }:
let
  cfg = config.services.spark;

  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../chart-archives/spark-9.3.5.tgz;
    chartName = "spark";
  };

  defaultNamespace = "spark";
  domain = cfg.domain;
  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    ingress = {
      enabled = true;
      hostname = domain;
      ingressClassName = "traefik";
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      tls = false;
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.spark = {
    enable = mkEnableOption "Enable application";

    domain = mkOption {
      description = mdDoc "The ingress domain";
      type = types.str;
      default = "spark.localhost";
    };

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
    applications.spark = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.spark = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
