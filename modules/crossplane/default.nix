{ lib, config, charts, nixidy, ... }:
let
  cfg = config.services.crossplane;

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.crossplane.io/master/";
    chart = "crossplane";
    version = "1.20.0-rc.0.24.g01782c157";
    chartHash = "sha256-mzXUVxHhDgJ9bPH+4Msr8lzlQ74PkK/tw+n9n0xYvYA=";
  };

  defaultNamespace = "crossplane";

  defaultValues = {
    image.pullPolicy = "Always";
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.crossplane = {
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

    applications.crossplane = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.crossplane = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
