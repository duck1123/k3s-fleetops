{ lib, ... }:
let
  homerDomain = "homer.dev.kronkltd.net";
  codeserverDomain = "codeserver.dev.kronkltd.net";
in {
  applications.homer = {
    namespace = "homer";
    createNamespace = true;

    helm.releases.homer = {
      chart = lib.helm.downloadHelmChart {
        repo = "https://charts.gabe565.com";
        chart = "homer";
        version = "0.7.0";
        chartHash = "sha256-Svr5oinmHRzpsJhqjocs5KKfi0LdEgYPui76r3uEnhI=";
      };

      values = {
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
    };
  };
}
