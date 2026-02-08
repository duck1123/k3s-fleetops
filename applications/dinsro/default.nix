{ config, lib, self, ... }:
with lib;
self.lib.mkArgoApp { inherit config lib; } {
  name = "dinsro";

  # https://artifacthub.io/packages/helm/kronkltd/dinsro
  chart = lib.helm.downloadHelmChart {
    repo = "https://chart.kronkltd.net/";
    chart = "dinsro";
    version = "0.1.7";
    chartHash = "sha256-hNLltCPAQ3Pibt4K5a+7557sT6Q0/8l1skGbHIsC1J0=";
  };

  uses-ingress = true;

  defaultValues = cfg: {
    database = {
      enabled = true;
      seed = true;
    };

    devcards = {
      enabled = false;
      ingress = {
        enabled = true;
        hosts = [
          {
            host = "devcards.dinsro.com";
            paths = [ { path = "/"; } ];
          }
        ];
        tls = [
          {
            hosts = [ "devcards.dinsro.com" ];
            secretName = "dinsro-com-devcards-tls";
          }
        ];
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
        hosts = [
          {
            host = "devtools.dinsro.com";
            paths = [ { path = "/"; } ];
          }
        ];
        tls = [
          {
            hosts = [ "devtools.dinsro.com" ];
            secretName = "dinsro-com-devtools-tls";
          }
        ];
      };
    };

    docs = {
      enabled = true;
      ingress = {
        enabled = true;
        hosts = [
          {
            host = "docs.dinsro.com";
            paths = [ { path = "/"; } ];
          }
        ];
        tls = [
          {
            hosts = [ "docs.dinsro.com" ];
            secretName = "dinsro-com-docs-tls";
          }
        ];
      };
    };

    image.tag = "4.0.3202";
    nrepl.enabled = false;
    notebooks = {
      enabled = true;
      ingress = {
        enabled = true;
        hosts = [
          {
            host = "notebooks.dinsro.com";
            paths = [ { path = "/"; } ];
          }
        ];
        tls = [
          {
            hosts = [ "notebooks.dinsro.com" ];
            secretName = "dinsro-com-notebooks-tls";
          }
        ];
      };
    };

    persistence = {
      enabled = true;
      seed = true;
    };

    ingress = with cfg.ingress; {
      enabled = true;
      hosts = [
        {
          host = domain;
          paths = [ { path = "/"; } ];
        }
      ];
      tls = [
        {
          hosts = [ domain ];
          secretName = "dinsro-com-tls";
        }
      ];
    };

    workspaces = {
      enabled = true;
      ingress = {
        enabled = true;
        hosts = [
          {
            host = "workspaces.dinsro.com";
            paths = [ { path = "/"; } ];
          }
        ];
        tls = [
          {
            hosts = [ "workspaces.dinsro.com" ];
            secretName = "dinsro-com-workspaces-tls";
          }
        ];
      };
    };
  };
}
