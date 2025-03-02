{ charts, config, lib, ... }:
let
  cfg = config.services.lldap;

  chartConfig = {
    repo = "https://charts.rock8s.com";
    chart = "lldap";
    version = "4.1.1";
    chartHash = "sha256-B1pmsE4zsl8saUnBBzljmJY6Lq6vrVuIeTMStpy3pPc=";
  };

  defaultNamespace = "lldap";
  domain = "lldap.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.lldap = {
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
    applications.lldap = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.lldap = { inherit chart values; };
    };
  };
}
