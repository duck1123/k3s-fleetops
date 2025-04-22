{ config, lib, pkgs, ... }:
let
  app-name = "harbor";
  cfg = config.services.${app-name};

  # https://artifacthub.io/packages/helm/bitnami/harbor
  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../charts/harbor-24.6.0.tgz;
    chartName = "harbor";
  };

  values = lib.attrsets.recursiveUpdate {
    # adminPassword = "naughtypassword";
    externalURL = "https://${cfg.domain}";

    ingress = {
      core = {
        ingressClassName = "traefik";
        hostname = cfg.domain;
        annotations = {
          "ingress.kubernetes.io/ssl-redirect" = "true";
          "ingress.kubernetes.io/proxy-body-size" = "0";
          "nginx.ingress.kubernetes.io/ssl-redirect" = "true";
          "nginx.ingress.kubernetes.io/proxy-body-size" = "0";
          "cert-manager.io/cluster-issuer" = cfg.clusterIssuer;
        };
        tls = true;
      };
    };
  } cfg.values;
in with lib; {
  options.services.${app-name} = {
    clusterIssuer = mkOption {
      description = mdDoc "The issuer";
      type = types.str;
      default = "letsencrypt-prod";
    };

    domain = mkOption {
      description = mdDoc "The domain";
      type = types.str;
      default = "harbor.localhost";
    };

    enable = mkEnableOption "Enable application";

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

      resources = {
        middlewares.allow-large-upload.spec.buffering = {
          maxRequestBodyBytes = 10737418240;
          maxResponseBodyBytes = 0;
          memRequestBodyBytes = 10485760;
          memResponseBodyBytes = 10485760;
        };
      };

      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
