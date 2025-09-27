{ ageRecipients, config, lib, pkgs, ... }:
with lib;
let password-secret = "minio-password";
in mkArgoApp { inherit config lib; } {
  name = "minio";

  # https://artifacthub.io/packages/helm/bitnami/minio
  chart = helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "minio";
    version = "17.0.6";
    chartHash = "sha256-njyO/PNrABMYShQ4Ix0VIMXvqOrPszoDT/s5jag49fQ=";
  };

  uses-ingress = true;

  extraOptions = {
    ingress.api-domain = mkOption {
      description = mdDoc "The ingress domain for the API";
      type = types.str;
      default = defaultApiDomain;
    };

    password = mkOption {
      description = mdDoc "The password";
      type = types.str;
      default = "CHANGEME";
    };
  };

  defaultValues = cfg: {
    auth = {
      existingSecret = password-secret;
      rootUserSecretKey = "user";
      rootPasswordSecretKey = "root-password";
    };

    console = {
      enabled = true;

      ingress = with cfg.ingress; {
        inherit ingressClassName;
        enabled = true;
        hostname = api-domain;
      };
    };

    ingress = with cfg.ingress; {
      inherit ingressClassName;
      enabled = true;
      hostname = domain;
      tls = tls.enable;
    };

    persistence.storageClass = "longhorn";
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
