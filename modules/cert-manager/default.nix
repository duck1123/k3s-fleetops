{ config, lib, ... }:
let
  cfg = config.services.cert-manager;

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.jetstack.io";
    chart = "cert-manager";
    version = "v1.17.1";
    chartHash = "sha256-CUKd2R911uTfr461MrVcefnfOgzOr96wk+guoIBHH0c=";
  };

  defaultNamespace = "cert-manager";

  defaultValues = { };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.cert-manager = {
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
    nixidy.resourceImports = [ ./generated.nix ];

    applications.cert-manager = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.cert-manager = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
