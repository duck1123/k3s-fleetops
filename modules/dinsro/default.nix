{ charts, config, lib, ... }:
let
  cfg = config.services.dinsro;

  chartConfig = {
    repo = "https://chart.kronkltd.net/";
    chart = "dinsro";
    version = "0.1.7";
    chartHash = "sha256-B1pmsE4zsl8saUnBBzljmJY6Lq6vrVuIeTMStpy3pPc=";
  };

  defaultNamespace = "dinsro";
  domain = "dinsro.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    database = {
      enabled = true;
      seed = true;
    };

    devcards = {
      enabled = false;
      ingress = {
        enabled = true;
        hosts = [{
          host = "devcards.dinsro.com";
          path = [{ path = "/"; }];
        }];
        tls = [{
          hosts = [ "devcards.dinsro.com" ];
          secretName = "dinsro-com-devcards-tls";
        }];
      };

      devtools = {
        enabled = true;
        ingress.enabled = true;
      };
    };

    devtools = {
      enabled = true;
      ingress = {
        enabled = true;
        hosts = [{
          host = "devtools.dinsro.com";
          paths = [{ path = "/"; }];
        }];
        tls = [{
          hosts = [ "devtools.dinsro.com" ];
          secretName = "dinsro-com-devtools-tls";
        }];
      };
    };

    docs = {
      enabled = true;
      ingress = {
        enabled = true;
        hosts = [{
          host = "docs.dinsro.com";
          paths = [{ path = "/"; }];
        }];
        tls = [{
          hosts = [ "docs.dinsro.com" ];
          secretName = "dinsro-com-docs-tls";
        }];
      };
    };

    image.tag = "4.0.3202";
    nrepl.enabled = false;
    notebooks = {
      enabled = true;
      ingress = {
        enabled = true;
        hosts = [{
          host = "notebooks.dinsro.com";
          paths = [{ path = "/"; }];
        }];
        tls = [{
          hosts = [ "notebooks.dinsro.com" ];
          secretName = "dinsro-com-notebooks-tls";
        }];
      };
    };

    persistence = {
      enabled = true;
      seed = true;
    };

    ingress = {
      enabled = true;
      hosts = [{
        host = "dinsro.com";
        paths = [{ path = "/"; }];
      }];
      tls = [{
        hosts = [ "dinsro.com" ];
        secretName = "dinsro-com-tls";
      }];
    };

    workspaces = {
      enabled = true;
      ingress = {
        enabled = true;
        hosts = [{
          host = "workspaces.dinsro.com";
          paths = [{ path = "/"; }];
        }];
        tls = [{
          hosts = [ "workspaces.dinsro.com" ];
          secretName = "dinsro-com-workspaces-tls";
        }];
      };
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.dinsro = {
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
    applications.dinsro = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.dinsro = { inherit chart values; };
    };
  };
}
