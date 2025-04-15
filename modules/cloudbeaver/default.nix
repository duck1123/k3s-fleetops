{ config, lib, ... }:
let
  app-name = "cloudbeaver";
  cfg = config.services.${app-name};

  # https://artifacthub.io/packages/helm/homeenterpriseinc/cloudbeaver
  chart = lib.helm.downloadHelmChart {
    repo = "https://homeenterpriseinc.github.io/helm-charts/";
    chart = "cloudbeaver";
    version = "0.6.0";
    chartHash = "sha256-+UuoshmHyNzVlWqpKP+DlWtgALnerkLdhx1ldQSorLk=";
  };

  defaultValues = {
    image.tag = "24.2.5";
    ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      enabled = false;
      hosts = [{
        host = cfg.domain;
        paths = [{
          path = "/";
          pathType = "ImplementationSpecific";
        }];
      }];
      tls = [ ];
    };
    persistence.enabled = false;
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.cloudbeaver = {
    clusterIssuer = mkOption {
      description = mdDoc "The cluster issuer for certificates";
      type = types.str;
      default = "letsencrypt-prod";
    };

    domain = mkOption {
      description = mdDoc "The ingress hostname";
      type = types.str;
      default = "${app-name}.localhost";
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
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.${app-name} = { inherit chart values; };

      resources.ingresses.cloudbeaver-ingress = {
        metadata.annotations = {
          # "cert-manager.io/cluster-issuer" = cfg.clusterIssuer;
          # "ingress.kubernetes.io/force-ssl-redirect" = "true";
          # "ingress.kubernetes.io/proxy-body-size" = "0";
          # "ingress.kubernetes.io/ssl-redirect" = "true";
          # "kubernetes.io/ingress.class" = "traefik";
        };
        spec = {
          # ingressClassName = "traefik";
          ingressClassName = "tailscale";
          rules = [{
            host = cfg.domain;
            http.paths = [{
              backend.service = {
                name = "cloudbeaver-svc";
                port.name = "http";
              };
              path = "/";
              pathType = "ImplementationSpecific";
            }];
          }];
          tls = [{
            hosts = [ cfg.domain ];
            secretName = "cloudbeaver-tls";
          }];
        };
      };

      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
