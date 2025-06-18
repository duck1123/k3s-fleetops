{ ageRecipients, config, lib, pkgs, ... }:
with lib;
let password-secret = "minio-password";
in mkArgoApp { inherit config lib; } {
  name = "minio";

  # https://artifacthub.io/packages/helm/bitnami/minio
  chart = helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "minio";
    version = "17.0.5";
    chartHash = "sha256-wF5UYkhwNJWu2encpxQbUrzJY5fQmDpaUunQ7y89tMQ=";
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

  defaultValues = (cfg: {
    apiIngress = with cfg.ingress; {
      inherit ingressClassName;
      enabled = true;
      hostname = api-domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      tls = tls.enable;
    };

    auth = {
      existingSecret = password-secret;
      rootUserSecretKey = "user";
      rootPasswordSecretKey = "root-password";
    };

    ingress = with cfg.ingress; {
      inherit ingressClassName;
      enabled = true;
      hostname = domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      tls = tls.enable;
    };
  });

  extraResources = cfg: {
    sopsSecrets.${password-secret} = lib.createSecret {
      inherit ageRecipients lib pkgs;
      inherit (cfg) namespace;
      secretName = password-secret;
      values = with cfg; { inherit password; };
    };
  };
}
