{ charts, config, lib, ... }:
let
  cfg = config.services.homer;

  chartConfig = {
    repo = "https://charts.gabe565.com";
    chart = "homer";
    version = "0.7.0";
    chartHash = "sha256-Svr5oinmHRzpsJhqjocs5KKfi0LdEgYPui76r3uEnhI=";
  };

  defaultNamespace = "homer";
  homerDomain = "homer.dev.kronkltd.net";
  codeserverDomain = "codeserver.dev.kronkltd.net";

  defaultValues = {
    ingress = {
      main = {
        enabled = true;
        hosts = [{
          host = homerDomain;
          paths = [{ path = "/"; }];
        }];
        tls = [{
          secretName = "homer-tls";
          hosts = [ homerDomain ];
        }];
      };

      addons.codeserver = {
        enabled = true;
        ingress = {
          enabled = true;
          hosts = [{
            host = codeserverDomain;
            paths = [{ path = "/"; }];
          }];
          tls = [{
            secretName = "codeserver-tls";
            hosts = [ codeserverDomain ];
          }];
        };
      };
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.homer = {
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
    applications.homer = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.homer = { inherit chart values; };
    };
  };
}
