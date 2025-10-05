{ charts, config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "grafana";

  # https://artifacthub.io/packages/helm/grafana/grafana
  chart = charts.grafana.grafana;

  uses-ingress = true;

  defaultValues = cfg: {
    ingress = with cfg.ingress; {
      inherit ingressClassName;

      enabled = true;
      hosts = [ domain ];

      tls = [{
        secretName = "grafana-tls";
        hosts = [ domain ];
      }];
    };

    persistence = {
      enabled = true;
      storageClassName = "longhorn";
    };
  };
}
