{ config, lib, ... }:
let
  app-name = "harbor-nix";
  cfg = config.services.${app-name};

  chart = lib.helm.downloadHelmChart {
    repo = "https://helm.goharbor.io";
    chart = "harbor";
    version = "1.16.0";
    chartHash = "sha256-B1pmsE4zsl8saUnBBzljmJY6Lq6vrVuIeTMStpy3pPc=";
  };

  defaultNamespace = "harbor";
  domain = "harbor.dev.kronkltd.net";
  registry-domain = "registry.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  # https://artifacthub.io/packages/helm/harbor/harbor
  values = lib.attrsets.recursiveUpdate {
    existingSecretAdminPassword = "harbor-admin-password";
    externalURL = "https://${domain}";
    internalTLS.enabled = false;
    expose = {
      ingress = {
        annotations = {
          "cert-manager.io/cluster-issuer" = clusterIssuer;
          "ingress.kubernetes.io/force-ssl-redirect" = "true";
          "ingress.kubernetes.io/proxy-body-size" = "0";
          "ingress.kubernetes.io/ssl-redirect" = "true";
        };
        type = "traefik";
        className = "traefik";
        hosts.core = domain;
      };
      tls = {
        certSource = "secret";
        enabled = false;
        secret.secretName = "harbor-tls";
      };
    };

    nginx.proxyBodySize = "10g";
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
      # helm.releases.${app-name} = { inherit chart values; };

      resources = {
        ingresses.harbor-registry-direct = {
          metadata = {
            annotations = {
              "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
              "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure";
              "traefik.ingress.kubernetes.io/router.middlewares" =
                "harbor-harbor-allow-large-upload@kubernetescrd";
            };
          };

          spec = {
            tls = [{
              hosts = [ registry-domain ];
              secretName = "harbor-registry-tls";
            }];
            rules = [{
              host = registry-domain;
              http.paths = [{
                path = "/";
                # pathType = "Prefix";
                pathType = "ImplementationSpecific";
                backend.service = {
                  name = "harbor-core";
                  port.number = 80;
                };
              }];
            }];
          };
        };

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
