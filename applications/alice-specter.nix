{ lib, ... }:
let domain = "specter-alice.dinsro.com";
in {
  applications.alice-specter = {
    namespace = "alice-specter";
    createNamespace = true;

    helm.releases.alice-specter = {
      chart = lib.helm.downloadHelmChart {
        repo = "https://chart.kronkltd.net/";
        chart = "specter-desktop";
        version = "0.1.0";
        chartHash = "sha256-lzGWuSAzOR/n5iBhg25einXA255SwTm0BRB88lUdEoE=";
      };

      values = {
        image.tag = "v1.10.3";
        ingress = {
          enabled = true;
          hosts = [{
            host = domain;
            paths = [{ path = "/"; }];
          }];
          tls = [{
            secretName = "alice-specter-prod-tls";
            hosts = [ domain ];
          }];
        };
        persistence.storageClassName = "local-path";
        # TODO: generate json
        nodeConfig = ''
          {"protocol":"http","external_node":true,"password":"rpcpassword","name":"alice","autodetect":false,"port":18443,"host":"alice-bitcoin","alias":"bar","fullpath":"/data/.specter/nodes/alice.json","datadir":"","user":"rpcuser"}'';
      };
    };
  };
}
