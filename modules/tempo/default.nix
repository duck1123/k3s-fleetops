{ charts, config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "tempo";

  chart = charts.grafana.tempo;

  uses-ingress = true;

  defaultValues = cfg: {
    persistence.enabled = true;
    tempo.retention = "72h";
    tempoQuery = {
      enabled = false;
      tag = "latest";
      ingress = with cfg.ingress; {
        enabled = true;
        annotations = {
          "cert-manager.io/cluster-issuer" = clusterIssuer;
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
}
