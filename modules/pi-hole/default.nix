{ config, lib, pkgs, ... }:
let
  app-name = "pihole";
  cfg = config.services.${app-name};

  # https://artifacthub.io/packages/helm/savepointsam/pihole?modal=values
  chart = lib.helm.downloadHelmChart {
    repo = "https://savepointsam.github.io/charts";
    chart = "pihole";
    version = "0.2.0";
    chartHash = "sha256-jwqcjoQXi41Y24t4uGqnw6JVhB2bBbiv5MasRTbq3hA=";
  };

  values = lib.attrsets.recursiveUpdate { } cfg.values;
in with lib; {
  options.services.${app-name} = {
    enable = mkEnableOption "Enable application";

    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = app-name;
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
