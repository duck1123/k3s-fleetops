{ ... }:
{
  flake.nixidyApps.cloudbeaver =
    {
      config,
      lib,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp { inherit config lib; } {
      name = "cloudbeaver";

      # https://artifacthub.io/packages/helm/avisto/cloudbeaver
      chart = helm.downloadHelmChart {
        repo = "https://avistotelecom.github.io/charts/";
        chart = "cloudbeaver";
        version = "1.1.3";
        chartHash = "sha256-/SDk4iHzH2MZFqY7KtUu5nMbBVcBEi5s1flT2ZbjD6k=";
      };

      uses-ingress = true;

      defaultValues = cfg: {
        ingress = with cfg.ingress; {
          inherit ingressClassName;

          annotations = {
            "cert-manager.io/cluster-issuer" = clusterIssuer;
            "ingress.kubernetes.io/force-ssl-redirect" = "true";
          };

          enabled = true;
          hostname = domain;
          tls = true;
        };

        nodeSelector."kubernetes.io/hostname" = cfg.hostAffinity;

        persistence = {
          enabled = true;
          storageClass = cfg.storageClassName;
        };
      };
    };
}
