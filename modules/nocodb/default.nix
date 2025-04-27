{ config, lib, pkgs, ... }:
let
  app-name = "nocodb";
  cfg = config.services.${app-name};

  # https://artifacthub.io/packages/helm/one-acre-fund/nocodb
  chart = lib.helm.downloadHelmChart {
    repo = "https://one-acre-fund.github.io/oaf-public-charts/";
    chart = "nocodb";
    version = "0.4.5";
    chartHash = "sha256-WPux8CNGrGhC+NXYntUTRNLi2BsJBY7DthqJcRuImyg=";
  };

  values = lib.attrsets.recursiveUpdate {
    # nocodb = {
    #   publicUrl = "";
    # };

    ingress = {
      enabled = true;
      className = cfg.ingressClassName;
      hosts = [{
        host = cfg.domain;
        paths = [{
          path = "/";
          pathType = "ImplementationSpecific";
        }];
      }];
      tls = [{
        secretName = "${app-name}-tls";
        hosts = [ cfg.domain ];
      }];
    };

    minio = {
      enabled = true;
    };
  } cfg.values;
in with lib; {
  options.services.${app-name} = {
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

    domain = mkOption {
      description = mdDoc "The domain";
      type = types.str;
      default = "${app-name}.localhost";
    };

    enable = mkEnableOption "Enable application";

    ingressClassName = mkOption {
      description = mdDoc "The Ingress class name";
      type = types.str;
      default = "traefik";
    };

    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = app-name;
    };

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    applications.${app-name} = {
      inherit (cfg) namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.${app-name} = { inherit chart values; };

      resources = { };

      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
