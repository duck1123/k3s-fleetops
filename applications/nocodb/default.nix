{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "nocodb";

  # https://artifacthub.io/packages/helm/one-acre-fund/nocodb
  chart = lib.helm.downloadHelmChart {
    repo = "https://one-acre-fund.github.io/oaf-public-charts/";
    chart = "nocodb";
    version = "0.4.5";
    chartHash = "sha256-WPux8CNGrGhC+NXYntUTRNLi2BsJBY7DthqJcRuImyg=";
  };

  uses-ingress = true;

  extraOptions = {
    databases = {
      minio = {
        bucketName = mkOption {
          description = mdDoc "The minio bucket name";
          type = types.str;
          default = "";
        };

        endpoint = mkOption {
          description = mdDoc "The minio endpoint";
          type = types.str;
          default = "";
        };

        region = mkOption {
          description = mdDoc "The minio region";
          type = types.str;
          default = "";
        };

        rootPassword = mkOption {
          description = mdDoc "The minio root password";
          type = types.str;
          default = "";
        };

        rootUser = mkOption {
          description = mdDoc "The minio root user";
          type = types.str;
          default = "";
        };
      };

      postgresql = {
        database = mkOption {
          description = mdDoc "The postgresql database";
          type = types.str;
          default = "";
        };

        password = mkOption {
          description = mdDoc "The postgresql password";
          type = types.str;
          default = "";
        };

        postgresPassword = mkOption {
          description = mdDoc "The postgresql postgresql password";
          type = types.str;
          default = "";
        };

        replicationPassword = mkOption {
          description = mdDoc "The postgresql replication password";
          type = types.str;
          default = "";
        };

        username = mkOption {
          description = mdDoc "The postgresql username";
          type = types.str;
          default = "";
        };
      };

      redis = {
        password = mkOption {
          description = mdDoc "The redis password";
          type = types.str;
          default = "";
        };
      };
    };
  };

  defaultValues = cfg: {
    ingress = with cfg.ingress; {
      enabled = true;
      className = ingressClassName;
      hosts = [
        {
          host = domain;
          paths = [
            {
              path = "/";
              pathType = "ImplementationSpecific";
            }
          ];
        }
      ];
      tls = [
        {
          secretName = tls.secretName;
          hosts = [ domain ];
        }
      ];
    };

    minio = {
      enabled = true;
    };

    postgresql = {
      enabled = true;
    };
  };
}
