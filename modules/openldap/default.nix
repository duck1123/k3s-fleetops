{ config, lib, ... }:
let
  cfg = config.services.openldap;

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.rock8s.com";
    chart = "openldap";
    version = "4.1.1";
    chartHash = "sha256-KXaKUUkqmg66urgTybvSNH67FjrJEt68sRWP2gFSM98=";
  };

  defaultNamespace = "openldap";
  domain = "ldap.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    replicaCount = 1;
    openldap.hostname = domain;
    tls.secret = "openldap-tls";
    env = {
      LDAP_ORGANISATION = "KRONK Ltd.";
      LDAP_DOMAIN = domain;
    };
    ingress.phphldapadmin = {
      certificate = "phpldapadmin-tls";
      enabled = true;
      hostname = "phpldapadmin.dev.kronkltd.net";
    };
    phpldapadmin.ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      hosts = "phpldapadmin.dev.kronkltd.net";
    };

    ltb-passwd.ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      hosts = [ "ltb.dev.kronkltd.net" ];
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.openldap = {
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
    applications.openldap = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.openldap = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
