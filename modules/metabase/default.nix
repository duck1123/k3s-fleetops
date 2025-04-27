{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "metabase";

  chart = lib.helm.downloadHelmChart {
    repo = "https://pmint93.github.io/helm-charts";
    chart = "metabase";
    version = "2.18.0";
    chartHash = "sha256-jrTqPX/fBMuu01Y9HJ100m1Tr7gEuaUecpt8jIJATL4=";
  };

  uses-ingress = true;

  defaultValues = cfg: {
    replicaCount = 1;
    monitoring.enabled = true;
    ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      enabled = true;
      hosts = [ domain ];
      tls = [{
        secretName = "metabase-tls";
        hosts = [ domain ];
      }];
    };
  };

  extraResources = {
    apps.v1.Deployment.metabase.spec.template.spec.containers.metabase.ports.protocol = "TCP";
  };
}
