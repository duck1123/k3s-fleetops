{ charts, config, lib, ... }:
let
  cfg = config.services.traefik;

  chart = lib.helm.downloadHelmChart {
    repo = "https://traefik.github.io/charts";
    chart = "traefik";
    version = "23.0.1";
    chartHash = "sha256-V6krhjJAI6/HFriKg48mPbd3Khe275BmrUJ80My+m9U=";
  };

  defaultNamespace = "traefik";

  defaultValues = { };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.traefik = {
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
    applications.traefik = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.traefik = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
