{ config, lib, ... }:
let
  app-name = "satisfactory";

  cfg = config.services."${app-name}";

  # https://artifacthub.io/packages/helm/schichtel/satisfactory
  chart = lib.helm.downloadHelmChart {
    repo = "https://schich.tel/helm-charts";
    chart = "satisfactory";
    version = "0.3.1";
    chartHash = "sha256-3LMR39pvNgS5Nyn3YQPZEVGY0XPse2UZw474H3OhsV4=";
  };

  values = lib.attrsets.recursiveUpdate {
    env = [
      {
        name = "DEBUG";
        value = "true";
      }
      {
      name = "STEAM_BETA";
      value = "true";
    }];
    satisfactoryOpts = { };
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
