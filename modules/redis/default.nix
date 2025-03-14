{ config, lib, ... }:
let
  cfg = config.services.redis;

  # https://artifacthub.io/packages/helm/bitnami/redis
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "redis";
    version = "20.11.3";
    chartHash = "sha256-GEX81xoTnfMnXY66ih0Ksx5QsXx/3H0L03BnNZQ/7Y4=";
  };

  defaultNamespace = "redis";

  defaultValues = {
    auth = {
      existingSecret = "redis-password";
      existingSecretPasswordKey = "password";
    };

    replicas.replicaCount = 1;
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.redis = {
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
    applications.redis = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.redis = { inherit chart values; };

      resources.sealedSecrets.redis-password.spec = {
        encryptedData.password = "AgCa80BfRlf3Crdnd9aaztAxKKv6Ml9C8yE9udSTolUdLYHCuLFDJPV/nKVOghVvS/7qO3H06W+q+K+pAAtLL8Sb5rIkXjbAeS4s7tLXEWtZvp8k0RkwuI4que2XJXwhYRzydCyw2cPtsFaxfP281pSonWbC5A3uiVuZWCyo0QgX7dA3Lzupl1AjAFGyAsonPQy6F5f4Z1f9u3nRJM9VHOjPN6vmTodN6AsRNidNe1MJ5Ji5rswu8QblAhKVc/o8302ytS/CCxdDYdkBqZo1Tqa2FXQF1LoCPskiBFQ5hk6gdMbw2DN4XLaFdaOx2RbD+zuk9H3JVUjvrN3QAeLX9h1QFKfpkRYx3mEWnXfvvFo1OU9mVmqBbDv+5l6vqOoiAaE5g9jyiATRZA/XBAfDGMFEpdiNxzK+HMjemgtG6dE0O0Ks6V2AYZIlKUuOqy+QHM19UHVNG88Q77AoQ/v+t/ernF9JaI5QUORSnN1kHnwbfxVjvQ2g6M72IW+xAptC8ciSUBEXtXYC6QBRYCkDnLiR/7718Um08lhM8yyvHPPvWyIteEnfoEZ/pWCtfuyeYG6EjitT/Iw8kXlfEkbXUMVoyzpFAMSfyF6fDsytLj17apQrofCSt1J5j6J33YwVUwh1BWE9lLS1akMRdE0b0sDwMXBgUiZvudPjeJt0+TAM694X9l0asaorIERaZmC6eYX6pP4axwANWlR6KCqvKBmbZTwkOQ==";
        template.metadata = {
          inherit namespace;
          name = "redis-password";
        };
      };

      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
