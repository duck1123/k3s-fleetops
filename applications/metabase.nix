{ ... }:
{
  flake.nixidyApps.metabase =
    {
      config,
      lib,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp { inherit config lib; } {
      name = "metabase";

      # https://artifacthub.io/packages/helm/pmint93/metabase
      chart = lib.helm.downloadHelmChart {
        repo = "https://pmint93.github.io/helm-charts";
        chart = "metabase";
        version = "2.27.6";
        chartHash = "sha256-9QwOq5ivvOvagEu99HZYjCRnakfv7aF9s+lY4Uho3/w=";
      };

      uses-ingress = true;

      defaultValues = cfg: {
        ingress = with cfg.ingress; {
          annotations = {
            "cert-manager.io/cluster-issuer" = clusterIssuer;
            "ingress.kubernetes.io/force-ssl-redirect" = "true";
          };
          className = ingressClassName;
          enabled = true;
          hosts = [ domain ];
          tls = [
            {
              secretName = "metabase-tls";
              hosts = [ domain ];
            }
          ];
        };

        monitoring.enabled = true;
        replicaCount = 1;
      };
    };
}
