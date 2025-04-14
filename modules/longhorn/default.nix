{ config, lib, ... }:
let
  app-name = "longhorn";
  cfg = config.services.longhorn;

  # https://artifacthub.io/packages/helm/longhorn/longhorn
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.longhorn.io";
    chart = "longhorn";
    version = "1.8.1";
    chartHash = "sha256-tRepKwXa0GS4/vsQQrs5DQ/HMzhsoXeiUsXh6+sSMhw=";
  };

  defaultNamespace = "longhorn-system";

  values = lib.attrsets.recursiveUpdate {
    defaultSettings = {
      defaultReolicaCount = 1;
    };

    persistence = {
      defaultClassReplicaCount = 1;
    };

    longhornUI = {
      replicas = 1;
    };

    ingress = {
      enabled = true;
      host = "longhorn.localhost";
    };

    preUpgradeChecker.jobEnabled = false;
  } cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.${app-name} = {
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
    applications.${app-name} = {
      inherit (cfg) namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.longhorn = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
