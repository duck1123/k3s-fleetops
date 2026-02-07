{ config, lib, ... }:
let
  cfg = config.services.sqlpad;

  chart = lib.helm.downloadHelmChart {
    repo = "https://chart.kronkltd.net/";
    chart = "sqlpad";
    version = "0.1.0";
    chartHash = "sha256-NVGvY+hjeL80Aa7T/AJzqWusHhLA3SKnpzOjJo6g40A=";
  };

  defaultNamespace = "sqlpad";
  domain = "sqlpad.dev.kronkltd.net";

  defaultValues = { };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in
with lib;
{
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
    applications.sqlpad = {
      inherit namespace;
      createNamespace = true;
      finalizer = "foreground";
      helm.releases.sqlpad = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
