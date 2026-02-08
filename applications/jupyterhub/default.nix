{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  hub-secret = "jupyterhub-hub2";
  postgresql-secret = "jupyterhub-postgresql";
in
mkArgoApp { inherit config lib; } {
  name = "jupyterhub";

  # https://artifacthub.io/packages/helm/bitnami/jupyterhub
  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../chart-archives/jupyterhub-8.1.5.tgz;
    chartName = "jupyterhub";
  };

  uses-ingress = true;

  extraOptions = {
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

    password = mkOption {
      description = mdDoc "The admin user password";
      type = types.str;
      default = "CHANGEME";
    };

    postgresql = {
      adminPassword = mkOption {
        description = mdDoc "The admin password";
        type = types.str;
        default = "CHANGEME";
      };

      adminUsername = mkOption {
        description = mdDoc "The admin username";
        type = types.str;
        default = "admin";
      };

      replicationPassword = mkOption {
        description = mdDoc "The replication password";
        type = types.str;
        default = "CHANGEME";
      };

      userPassword = mkOption {
        description = mdDoc "The user password";
        type = types.str;
        default = "CHANGEME";
      };
    };

    proxyToken = mkOption {
      description = mdDoc "The proxy token";
      type = types.str;
      default = "CHANGEME";
    };
  };

  defaultValues = cfg: {
    hub = {
      adminUser = "admin";
      existingSecret = hub-secret;
    };

    postgresql.auth.existingSecret = postgresql-secret;

    proxy.ingress = with cfg.ingress; {
      inherit ingressClassName tls;
      enabled = true;
      hostname = domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
    };
  };

  extraResources =
    cfg:
    let
      hub-values = self.lib.toYAML {
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
        spec.secretTemplates = [
          {
            name = hub-secret;
            stringData = {
              "hub.config.CryptKeeper.keys" = cfg.cryptkeeperKeys;
              "hub.config.JupyterHub.cookie_secret" = cfg.cookieSecret;
              "proxy-token" = cfg.proxyToken;
              "values.yaml" = hub-values;
            };
          }
        ];
      };

      hub-secret-config-yaml = self.lib.toYAML {
        inherit pkgs;
        value = hub-secret-config;
      };

      encrypted-secret-config = lib.encryptString {
        inherit pkgs;
        inherit (config) ageRecipients;
        secretName = hub-secret;
        value = hub-secret-config-yaml;
      };

      encrypted-secret-config-object = builtins.fromJSON encrypted-secret-config;
    in
    {
      sopsSecrets = {
        ${hub-secret} = {
          inherit (encrypted-secret-config-object) sops spec;
        };

        ${postgresql-secret} = lib.createSecret {
          inherit lib pkgs;
          inherit (config) ageRecipients;
          inherit (cfg) namespace;
          inherit (self.lib) encryptString toYAML;
          secretName = postgresql-secret;
          values = {
            password = cfg.postgresql.adminPassword;
            postgres-password = cfg.postgresql.adminPassword;
          };
        };
      };
    };
}
