{ lib, ... }:
let domain = "tempo.dev.kronkltd.net";
in {
  applications.tempo = {
    namespace = "tempo";
    createNamespace = true;

    # metadata.finalizers = ["resources-finalizer.argocd.argoproj.io"];

    helm.releases.tempo = {
      chart = lib.helm.downloadHelmChart {
        repo = "https://grafana.github.io/helm-charts";
        chart = "tempo";
        version = "1.15.0";
        chartHash = "sha256-hmshN4RoUb9GVoyEdPObzhMmsdLMnNMEdJXmhFzg8Lg=";
      };

      values = {
        persistence.enabled = true;
        tempo.retention = "72h";
        tempoQuery = {
          enabled = false;
          tag = "latest";
          ingress = {
            enabled = true;
            annotations = {
              "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
              "ingress.kubernetes.io/force-ssl-redirect" = "true";
              "ingress.kubernetes.io/proxy-body-size" = "0";
              "ingress.kubernetes.io/ssl-redirect" = "true";
              "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure";
              "traefik.ingress.kubernetes.io/router.middlewares" =
                "authentik-middlewares-authenkik@kubernetescrd";
            };
            hosts = [ domain ];
            tls = [{
              secretName = "tempo-tls";
              hosts = [ domain ];
            }];
          };
        };
      };
    };
  };
}
