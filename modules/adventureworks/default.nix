{ charts, config, lib, ... }:
let
  cfg = config.services.adventureworks;
  chart = lib.helm.downloadHelmChart {
    repo = "https://chart.kronkltd.net/";
    version = "0.1.0";
    chartHash = "sha256-GMqmF862sBNjYrdbbS1nl9Fw0jbfwo5vj3dEpxZXHu0=";
    chart = "adventureworks";
  };
  defaultValues = { };
  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.adventureworks = {
    enable = mkEnableOption "Enable application";
    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = "adventureworks";
    };

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };

    version = mkOption {
      description = "The version to install";
      default = "0.1.0";
    };
  };

  config = mkIf cfg.enable {
    applications.adventureworks = {
      createNamespace = false;
      helm.releases.adventureworks = { inherit chart namespace values; };
      syncPolicy.finalSyncOpts = ["CreateNamespace=true"];
    };
  };
}
