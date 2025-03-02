{ charts, config, lib, ... }:
let
  cfg = config.services.mindsdb;

  chartConfig = {
    repo = "https://chart.kronkltd.net/";
    chart = "mindsdb";
    version = "0.1.0";
    chartHash = "sha256-BExMwx1a2ovklEratuFXVujdmPgLypQJKcNyh+630Ig=";
  };

  defaultNamespace = "mindsdb";
  domain = "mindsdb.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    ingress = {
      enabled = true;
      hosts = [{
        host = "mindsdb.dev.kronkltd.net";
        paths = [{
          path = "/";
          pathType = "ImplementationSpecific";
        }];
      }];
      tls = [{
        secretName = "mindsdb-tls";
        hosts = [ "mindsdb.dev.kronkltd.net" ];
      }];
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.mindsdb = {
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
    applications.mindsdb = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.mindsdb = { inherit chart values; };
    };
  };
}
