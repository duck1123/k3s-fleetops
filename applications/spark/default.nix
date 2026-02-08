{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib;
mkArgoApp { inherit config lib; } {
  name = "spark";

  # https://artifacthub.io/packages/helm/bitnami/spark
  chart = self.lib.helmChart {
    inherit pkgs;
    chartTgz = ../../chart-archives/spark-9.3.5.tgz;
    chartName = "spark";
  };

  uses-ingress = true;

  defaultValues =
    cfg: with cfg.ingress; {
      ingress = {
        inherit ingressClassName;
        annotations = {
          "cert-manager.io/cluster-issuer" = clusterIssuer;
          "ingress.kubernetes.io/force-ssl-redirect" = "true";
        };
        enabled = true;
        hostname = domain;
        tls = tls.enable;
      };
    };
}
