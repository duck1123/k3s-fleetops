{ config, lib, ... }:
let
  cfg = config.services.harbor;

  chart = lib.helm.downloadHelmChart {
    repo = "https://helm.goharbor.io";
    chart = "harbor";
    version = "1.16.0";
    chartHash = "sha256-B1pmsE4zsl8saUnBBzljmJY6Lq6vrVuIeTMStpy3pPc=";
  };

  defaultNamespace = "harbor";
  domain = "harbor.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
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
        className = "traefik";
        hosts.core = domain;
      };
      tls = {
        certSource = "secret";
        enabled = false;
        secret.secretName = "harbor-tls";
      };
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.harbor = {
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
    applications.harbor = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.harbor = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
