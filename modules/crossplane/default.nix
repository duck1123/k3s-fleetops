{ config, lib, ... }:
let
  app-name = "crossplane";
  cfg = config.services.${app-name};

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.crossplane.io/master/";
    chart = "crossplane";
    version = "1.20.0-rc.0.24.g01782c157";
    chartHash = "sha256-mzXUVxHhDgJ9bPH+4Msr8lzlQ74PkK/tw+n9n0xYvYA=";
  };

  defaultValues = { image.pullPolicy = "Always"; };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
in with lib; {
  imports = [ ./providers ];

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

    nixidy.resourceImports = [ ./generated.nix ];
  };
}
