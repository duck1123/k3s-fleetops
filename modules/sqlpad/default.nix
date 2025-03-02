{ charts, config, lib, ... }:
let
  cfg = config.services.sqlpad;

  chartConfig = {
    repo = "https://chart.kronkltd.net/";
    chart = "sqlpad";
    version = "0.1.0";
    chartHash = "sha256-Svr5oinmHRzpsJhqjocs5KKfi0LdEgYPui76r3uEnhI=";
  };

  defaultNamespace = "sqlpad";
  domain = "sqlpad.dev.kronkltd.net";

  defaultValues = {
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.sqlpad = {
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
    applications.sqlpad = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.sqlpad = { inherit chart values; };
    };
  };
}
