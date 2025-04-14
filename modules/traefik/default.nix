{ config, lib, ... }:
let
  app-name = "traefik";
  cfg = config.services.traefik;

  chart = lib.helm.downloadHelmChart {
    repo = "https://traefik.github.io/charts";
    chart = "traefik";
    version = "35.0.0";
    chartHash = "sha256-fY34pxXS/Uyvpcl0TmV6dIlrItLMKlNK1FEPmjsWr4M=";
  };

  values = lib.attrsets.recursiveUpdate {
    # providers.kubernetesGateway.statusAddress.hostname = "localhost";
  } cfg.values;
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
