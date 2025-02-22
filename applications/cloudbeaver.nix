{ lib, ... }: {
  applications.cloudbeaver = {
    namespace = "cloudbeaver";
    createNamespace = true;

    helm.releases.cloudbeaver = {
      chart = lib.helm.downloadHelmChart {
        repo = "https://homeenterpriseinc.github.io/helm-charts/";
        chart = "cloudbeaver";
        version = "0.6.0";
        chartHash = "sha256-+UuoshmHyNzVlWqpKP+DlWtgALnerkLdhx1ldQSorLk=";
      };
      values = {
        image.tag = "24.2.5";
        ingress = {
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
            "ingress.kubernetes.io/force-ssl-redirect" = "true";
          };
          enabled = true;
          hosts = [{
            host = "cloudbeaver.dev.kronkltd.net";
            paths = [{
              path = "/";
              pathType = "ImplementationSpecific";
            }];
          }];
          tls = [ ];
        };
        persistence.enabled = false;
      };
    };
  };
}
