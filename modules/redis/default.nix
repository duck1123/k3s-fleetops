{ config, lib, pkgs, ... }:
with lib;
let redis-password-secret = "redis-password";
in mkArgoApp { inherit config lib; } {
  name = "redis";

  # https://artifacthub.io/packages/helm/bitnami/redis
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "redis";
    version = "20.11.3";
    chartHash = "sha256-GEX81xoTnfMnXY66ih0Ksx5QsXx/3H0L03BnNZQ/7Y4=";
  };

  uses-ingress = true;

  extraOptions.password = mkOption {
    description = mdDoc "The password";
    type = types.str;
    default = "CHANGEME";
  };

  defaultValues = cfg: {
    auth = {
      existingSecret = redis-password-secret;
      existingSecretPasswordKey = "password";
    };

    global.defaultStorageClass = "longhorn";
    replicas.replicaCount = 1;
  };

  extraResources = cfg: {
    sopsSecrets.redis-password = let
      name = redis-password-secret;
      secret-object = builtins.fromJSON (lib.encryptString {
        secretName = name;
        value = lib.toYAML {
          inherit pkgs;
          value = {
            apiVersion = "isindir.github.com/v1alpha3";
            kind = "SopsSecret";
            metadata = {
              inherit name;
              inherit (cfg) namespace;
            };
            spec.secretTemplates = [{
              inherit name;
              stringData.password = cfg.password;
            }];
          };
        };
      });
    in { inherit (secret-object) sops spec; };
  };
}
