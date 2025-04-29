{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "sops";

  # https://artifacthub.io/packages/helm/sops-secrets-operator/sops-secrets-operator
  chart = lib.helm.downloadHelmChart {
    repo = "https://isindir.github.io/sops-secrets-operator/";
    chart = "sops-secrets-operator";
    version = "0.21.0";
    chartHash = "sha256-SmSp9oo8ue9DuRQSHevJSrGVVB5xmmlook53Y8AfUZY=";
  };

  defaultValues = cfg: {
    extraEnv = [{
      name = "SOPS_AGE_KEY_FILE";
      value = "/etc/sops-age-key-file/key";
    }];
    secretsAsFiles = [{
      mountPath = "/etc/sops-age-key-file";
      name = "sops-age-key-file";
      secretName = "sops-age-key-file";
    }];
  };

  extraConfig = cfg: { nixidy.resourceImports = [ ./generated.nix ]; };
}
