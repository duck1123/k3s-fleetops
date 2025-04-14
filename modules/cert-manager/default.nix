{ config, lib, ... }:
let
  app-name = "cert-manager";
  cfg = config.services.${app-name};

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.jetstack.io";
    chart = "cert-manager";
    version = "v1.17.1";
    chartHash = "sha256-CUKd2R911uTfr461MrVcefnfOgzOr96wk+guoIBHH0c=";
  };

  values = lib.attrsets.recursiveUpdate { crds.enabled = true; } cfg.values;
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
    nixidy.resourceImports = [ ./generated.nix ];

    applications.${app-name} = {
      inherit (cfg) namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.${app-name} = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
