{ charts, config, lib, pkgs, ... }:
let
  cfg = config.services.keycloak;

  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../charts/keycloak-24.1.0.tgz;
    chartName = "keycloak";
  };

  defaultNamespace = "keycloak";
  domain = "keycloak.dev.kronkltd.net";
  adminDomain = "keycloak-admin.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    auth = {
      adminUser = "admin";
      existingSecret = "keycload-admin-password";
      passwordSecretKey = "password";
    };

    ingress = {
      enabled = true;
      ingressClassName = "traefik";
      hostname = domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      tls = true;
    };

    adminIngress = {
      enabled = true;
      ingressClassName = "traefik";
      hostname = adminDomain;
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      tls = true;
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.keycloak = {
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
    applications.keycloak = {
      inherit namespace;
      createNamespace = true;
      helm.releases.keycloak = { inherit chart values; };
    };
  };
}
