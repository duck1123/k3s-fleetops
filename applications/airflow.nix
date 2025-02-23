{ lib, ... }:
let
  domain = "airflow.dev.kronkltd.net";
  clusterIssuer = "letsencrypt-prod";
in {
  applications.airflow = {
    namespace = "airflow";
    createNamespace = true;

    helm.releases.argo-events = {
      chart = lib.helm.downloadHelmChart {
        repo = "https://airflow.apache.org";
        chart = "airflow";
        version = "1.15.0";
        chartHash = "sha256-sYiZkYjnBqmhe/4vISvUXUQx2r+XHAd9bhWGrkn4tKM=";
      };

      values = {
        createUserJob = {
          applyCustomEnv = false;
          useHelmHooks = false;
        };

        ingress.web = {
          annotations = { "cert-manager.io/cluster-issuer" = clusterIssuer; };
          enabled = true;
          hosts = [{
            name = domain;
            tls = {
              enabled = true;
              secretName = "airflow-tls";
            };
          }];
        };

        migrateDatabaseJob = {
          applyCustomEnv = false;
          useHelmHooks = false;
        };
      };
    };
  };
}
