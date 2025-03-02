{ charts, config, lib, ... }:
let
  cfg = config.services.keycloak;

  chartConfig = {
    repo = "https://helm.gokeycloak.io";
    chart = "keycloak";
    version = "1.16.0";
    chartHash = "sha256-B1pmsE4zsl8saUnBBzljmJY6Lq6vrVuIeTMStpy3pPc=";
  };

  defaultNamespace = "keycloak";
  domain = "keycloak.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.keycloak = {
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
    applications.keycloak = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.keycloak = { inherit chart values; };
    };
  };
}
