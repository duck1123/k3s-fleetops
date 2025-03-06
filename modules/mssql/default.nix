{ charts, config, lib, ... }:
let
  cfg = config.services.mssql;

  chart = lib.helm.downloadHelmChart {
    repo = "https://simcubeltd.github.io/simcube-helm-charts/";
    chart = "mssqlserver-2022";
    version = "1.2.3";
    chartHash = "sha256-IdqGRmO6dAeupsqtT7YVqE080GRC8kYL5aM7keV8JTk=";
  };

  defaultNamespace = "mssql";

  defaultValues = { acceptEula.value = "yes"; };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in {
  options.services.mssql = with lib; {
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

  config = lib.mkIf cfg.enable {
    applications.mssql = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.mssql = { inherit chart values; };
    };
  };
}
