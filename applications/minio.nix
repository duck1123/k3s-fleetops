{ lib, ... }: {
  applications.minio = {
    namespace = "minio";
    createNamespace = true;

    helm.releases.minio = {
      chart = lib.helm.downloadHelmChart {
        repo = "https://charts.bitnami.com/bitnami";
        chart = "minio";
        version = "14.8.5";
        chartHash = "sha256-zP40G0NweolTpH/Fnq9nOe486n39MqJBqQ45GwJEc1I=";
      };
      values = {
        apiIngress = {
          enabled = true;
          ingressClassName = "traefik";
          hostname = "minio-api.dev.kronkltd.net";
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
            "ingress.kubernetes.io/force-ssl-redirect" = "true";
            "ingress.kubernetes.io/proxy-body-size" = "0";
            "ingress.kubernetes.io/ssl-redirect" = "true";
          };
          tls = true;
        };

        auth = {
          existingSecret = "minio-password";
          rootUserSecretKey = "user";
        };
      };
    };
  };
}
