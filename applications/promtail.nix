{ ... }:
{
  flake.nixidyApps.promtail =
    {
      charts,
      config,
      lib,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp { inherit config lib; } {
      name = "promtail";

      # https://artifacthub.io/packages/helm/grafana/promtail
      chart = charts.grafana.promtail;

      extraOptions = {
        lokiUrl = mkOption {
          description = mdDoc "Loki push API endpoint";
          type = types.str;
          default = "http://loki-gateway.loki.svc.cluster.local/loki/api/v1/push";
        };
      };

      defaultValues = cfg: {
        # DaemonSet collecting container logs from every node
        config = {
          clients = [
            { url = cfg.lokiUrl; }
          ];
        };
      };
    };
}
