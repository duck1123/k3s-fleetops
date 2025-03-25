{ config, lib, pkgs, ... }:
let
  app-name = "jupyterhub";

  cfg = config.services."${app-name}";

  # https://artifacthub.io/packages/helm/bitnami/jupyterhub
  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../charts/jupyterhub-8.1.5.tgz;
    chartName = "jupyterhub";
  };

  defaultNamespace = "jupyterhub";
  # domain = "jupyterhub.localhost";
  domain = "jupyterhub.dev.kronkltd.net";
  tls-secret-name = "jupyterhub-tls";
  clusterIssuer = "letsencrypt-prod";
  postgresql-secret = "postgresql-credentials";

  defaultValues = {
    hub = {
      adminUser = "admin";
    };

    postgresql.auth.existingSecret = postgresql-secret;

    proxy.ingress = {
      enabled = true;
      ingressClassName = "traefik";
      hostname = domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      tls = true;
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services."${app-name}" = {
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
    applications."${app-name}" = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases."${app-name}" = { inherit chart values; };

      resources.sealedSecrets."${postgresql-secret}".spec = {
        encryptedData.password = "AgCa80BfRlf3Crdnd9aaztAxKKv6Ml9C8yE9udSTolUdLYHCuLFDJPV/nKVOghVvS/7qO3H06W+q+K+pAAtLL8Sb5rIkXjbAeS4s7tLXEWtZvp8k0RkwuI4que2XJXwhYRzydCyw2cPtsFaxfP281pSonWbC5A3uiVuZWCyo0QgX7dA3Lzupl1AjAFGyAsonPQy6F5f4Z1f9u3nRJM9VHOjPN6vmTodN6AsRNidNe1MJ5Ji5rswu8QblAhKVc/o8302ytS/CCxdDYdkBqZo1Tqa2FXQF1LoCPskiBFQ5hk6gdMbw2DN4XLaFdaOx2RbD+zuk9H3JVUjvrN3QAeLX9h1QFKfpkRYx3mEWnXfvvFo1OU9mVmqBbDv+5l6vqOoiAaE5g9jyiATRZA/XBAfDGMFEpdiNxzK+HMjemgtG6dE0O0Ks6V2AYZIlKUuOqy+QHM19UHVNG88Q77AoQ/v+t/ernF9JaI5QUORSnN1kHnwbfxVjvQ2g6M72IW+xAptC8ciSUBEXtXYC6QBRYCkDnLiR/7718Um08lhM8yyvHPPvWyIteEnfoEZ/pWCtfuyeYG6EjitT/Iw8kXlfEkbXUMVoyzpFAMSfyF6fDsytLj17apQrofCSt1J5j6J33YwVUwh1BWE9lLS1akMRdE0b0sDwMXBgUiZvudPjeJt0+TAM694X9l0asaorIERaZmC6eYX6pP4axwANWlR6KCqvKBmbZTwkOQ==";
        template.metadata = {
          inherit namespace;
          name = postgresql-secret;
        };
      };


      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
