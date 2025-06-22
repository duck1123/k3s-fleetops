{ ageRecipients, config, lib, pkgs, ... }:
let
  app-name = "jupyterhub";

  cfg = config.services."${app-name}";

  # https://artifacthub.io/packages/helm/bitnami/jupyterhub
  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../chart-archives/jupyterhub-8.1.5.tgz;
    chartName = "jupyterhub";
  };

  # clusterIssuer = "letsencrypt-prod";
  clusterIssuer = "tailscale";
  ingressClassName = "tailscale";

  hub-secret = "jupyterhub-hub2";
  postgresql-secret = "jupyterhub-postgresql";

  hub-values = lib.toYAML {
    inherit pkgs;
    value = import ./config.nix { inherit (cfg) password; };
  };

  hub-secret-config = {
    apiVersion = "isindir.github.com/v1alpha3";
    kind = "SopsSecret";
    metadata = {
      name = hub-secret;
      inherit (cfg) namespace;
    };
    spec.secretTemplates = [{
      name = hub-secret;
      stringData = {
        "hub.config.CryptKeeper.keys" = cfg.cryptkeeperKeys;
        "hub.config.JupyterHub.cookie_secret" = cfg.cookieSecret;
        "proxy-token" = cfg.proxyToken;
        "values.yaml" = hub-values;
      };
    }];
  };

  hub-secret-config-yaml = lib.toYAML {
    inherit pkgs;
    value = hub-secret-config;
  };

  encrypted-secret-config = lib.encryptString {
    inherit ageRecipients pkgs;
    secretName = hub-secret;
    value = hub-secret-config-yaml;
  };

  encrypted-secret-config-object = builtins.fromJSON encrypted-secret-config;

  values = lib.attrsets.recursiveUpdate {
    hub = {
      adminUser = "admin";
      existingSecret = hub-secret;
    };

    postgresql.auth.existingSecret = postgresql-secret;

    proxy.ingress = {
      inherit ingressClassName;
      enabled = true;
      hostname = cfg.domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      tls = cfg.ssl;
    };
  } cfg.values;
in with lib; {
  options.services.${app-name} = {
    cookieSecret = mkOption {
      description = mdDoc "The cookie secret";
      type = types.str;
      default = "CHANGEME";
    };

    cryptkeeperKeys = mkOption {
      description = mdDoc "The cryptkeeper keys";
      type = types.str;
      default = "CHANGEME";
    };

    domain = mkOption {
      description = mdDoc "The ingress domain";
      type = types.str;
      default = "jupyterhub.localhost";
    };

    enable = mkEnableOption "Enable application";

    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = app-name;
    };

    password = mkOption {
      description = mdDoc "The admin user password";
      type = types.str;
      default = "CHANGEME";
    };

    proxyToken = mkOption {
      description = mdDoc "The proxy token";
      type = types.str;
      default = "CHANGEME";
    };

    ssl = mkEnableOption "Should SSL be used?";

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

      resources.sopsSecrets.${hub-secret} = {
        inherit (encrypted-secret-config-object) sops spec;
      };

      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
