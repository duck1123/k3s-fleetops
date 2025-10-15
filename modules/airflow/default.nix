{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "airflow";

  chart = lib.helm.downloadHelmChart {
    repo = "https://airflow.apache.org";
    chart = "airflow";
    version = "1.15.0";
    chartHash = "sha256-sYiZkYjnBqmhe/4vISvUXUQx2r+XHAd9bhWGrkn4tKM=";
  };

  uses-ingress = true;

  extraOptions = {
    ingress.api-domain = mkOption {
      description = mdDoc "The ingress domain for the API";
      type = types.str;
      default = defaultApiDomain;
    };
  };

  defaultValues = cfg: {
    createUserJob = {
      applyCustomEnv = false;
      useHelmHooks = false;
    };

    ingress.web = with cfg.ingress; {
      annotations = { "cert-manager.io/cluster-issuer" = clusterIssuer; };
      enabled = true;
      hosts = [{
        name = domain;
        tls = with tls; {
          inherit secretName;
          enabled = enable;
        };
      }];
    };

    migrateDatabaseJob = {
      applyCustomEnv = false;
      useHelmHooks = false;
    };
  };
}
