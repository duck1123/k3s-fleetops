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

  defaultNamespace = "harbor";
  domain = "harbor.dev.kronkltd.net";
  clusterIssuer = "letsencrypt-prod";

  values = lib.attrsets.recursiveUpdate {
    adminPassword = "naughtypassword";
    externalURL = "https://${domain}";

    ingress = {
      core = {
        ingressClassName = "traefik";
        hostname = domain;
        annotations = {
          "ingress.kubernetes.io/ssl-redirect" = "true";
          "ingress.kubernetes.io/proxy-body-size" = "0";
          "nginx.ingress.kubernetes.io/ssl-redirect" = "true";
          "nginx.ingress.kubernetes.io/proxy-body-size" =  "0";
          "cert-manager.io/cluster-issuer" = clusterIssuer;
        };
        tls = true;
      };
    };
  } cfg.values;
in with lib; {
  options.services.${app-name} = {
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
    applications.${app-name} = {
      inherit (cfg) namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.${app-name} = { inherit chart values; };

      resources = {
        # ingresses.harbor-registry-direct = {
        #   metadata = {
        #     annotations = {
        #       "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        #       "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure";
        #       "traefik.ingress.kubernetes.io/router.middlewares" =
        #         "harbor-harbor-allow-large-upload@kubernetescrd";
        #     };
        #   };

        #   spec = {
        #     tls = [{
        #       hosts = [ registry-domain ];
        #       secretName = "harbor-registry-tls";
        #     }];
        #     rules = [{
        #       host = registry-domain;
        #       http.paths = [{
        #         path = "/";
        #         # pathType = "Prefix";
        #         pathType = "ImplementationSpecific";
        #         backend.service = {
        #           name = "harbor-core";
        #           port.number = 80;
        #         };
        #       }];
        #     }];
        #   };
        # };

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
