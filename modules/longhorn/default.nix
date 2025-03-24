{ charts, config, lib, ... }:
let
  cfg = config.services.longhorn;

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.longhorn.io";
    chart = "longhorn";
    version = "1.8.1";
    chartHash = "sha256-tRepKwXa0GS4/vsQQrs5DQ/HMzhsoXeiUsXh6+sSMhw=";
  };

  defaultNamespace = "longhorn-system";
  domain = "longhorn.dev.kronkltd.net";

  defaultValues = {
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
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.longhorn = {
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
    applications.longhorn = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.longhorn = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
