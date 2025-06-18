{ ageRecipients, config, lib, pkgs, ... }:
with lib;
let password-secret = "redis-password";
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
      existingSecret = password-secret;
      existingSecretPasswordKey = "password";
    };

    global.defaultStorageClass = "longhorn";
    replicas.replicaCount = 1;
  };

  extraResources = cfg: {
    sopsSecrets.${password-secret} = lib.createSecret {
      inherit ageRecipients lib pkgs;
      inherit (cfg) namespace;
      secretName = password-secret;
      values = with cfg; { inherit password; };
    };
  };
}
