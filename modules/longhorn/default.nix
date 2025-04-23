{ config, lib, ... }:
let
  app-name = "longhorn";
  cfg = config.services.${app-name};

  # https://artifacthub.io/packages/helm/longhorn/longhorn
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.longhorn.io";
    chart = "longhorn";
    version = "1.8.1";
    chartHash = "sha256-tRepKwXa0GS4/vsQQrs5DQ/HMzhsoXeiUsXh6+sSMhw=";
  };

  clusterIssuer = "letsencrypt-prod";

  values = lib.attrsets.recursiveUpdate {
    defaultSettings.defaultReplicaCount = 1;

    ingress = {
      enabled = true;
      host = cfg.domain;
      ingressClassName = "tailscale";
      tls = true;
      # annotations = {
      #   "cert-manager.io/cluster-issuer" = clusterIssuer;
      #   "ingress.kubernetes.io/force-ssl-redirect" = "true";
      # };
    };

    longhornUI.replicas = 1;
    persistence = {
      defaultClass = false;
      defaultClassReplicaCount = 1;
    };
    preUpgradeChecker.jobEnabled = false;
  } cfg.values;
in with lib; {
  options.services.${app-name} = {
    domain = mkOption {
      description = mdDoc "The longhorn ui domain";
      type = types.str;
      default = "longhorn.localhost";
    };
    enable = mkEnableOption "Enable application";
    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = "longhorn-system";
    };

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    applications.${app-name} = {
      inherit (cfg) namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.${app-name} = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
