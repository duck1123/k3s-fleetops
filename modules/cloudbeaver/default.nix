{ charts, config, lib, ... }:
let
  cfg = config.services.cloudbeaver;

  chart = lib.helm.downloadHelmChart {
    repo = "https://homeenterpriseinc.github.io/helm-charts/";
    chart = "cloudbeaver";
    version = "0.6.0";
    chartHash = "sha256-+UuoshmHyNzVlWqpKP+DlWtgALnerkLdhx1ldQSorLk=";
  };

  defaultNamespace = "cloudbeaver";
  domain = "cloudbeaver.dev.kronkltd.net";

  defaultValues = {
    image.tag = "24.2.5";
    ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      enabled = false;
      hosts = [{
        host = domain;
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
    applications.cloudbeaver = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.cloudbeaver = { inherit chart values; };

      resources.ingresses.cloudbeaver-ingress = {
        metadata.annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
          "ingress.kubernetes.io/force-ssl-redirect" = "true";
          "ingress.kubernetes.io/proxy-body-size" = "0";
          "ingress.kubernetes.io/ssl-redirect" = "true";
          "kubernetes.io/ingress.class" = "traefik";
        };
        spec = {
          ingressClassName = "traefik";
          rules = [{
            host = domain;
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
            hosts = [ domain ];
            secretName = "cloudbeaver-tls";
          }];
        };
      };

      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
