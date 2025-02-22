{ lib, ... }: {
  applications.harbor = {
    namespace = "harbor";
    createNamespace = true;

    helm.releases.harbor = {
      chart = lib.helm.downloadHelmChart {
        repo = "https://helm.goharbor.io";
        chart = "harbor";
        version = "1.16.0";
        chartHash = "sha256-B1pmsE4zsl8saUnBBzljmJY6Lq6vrVuIeTMStpy3pPc=";
      };
      values = {
        existingSecretAdminPassword = "harbor-admin-password";
        externalURL = "https://harbor.dev.kronkltd.net";
        expose = {
          ingress = {
            annotations = {
              "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
              "ingress.kubernetes.io/force-ssl-redirect" = "true";
              "ingress.kubernetes.io/proxy-body-size" = "0";
              "ingress.kubernetes.io/ssl-redirect" = "true";
            };
            className = "traefik";
            hosts.core = "harbor.dev.kronkltd.net";
          };
          tls = {
            certSource = "secret";
            secret.secretName = "harbor-tls";
          };
        };
      };
    };
  };
}
