{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "longhorn";
  namespace = "longhorn-system";

  # https://artifacthub.io/packages/helm/longhorn/longhorn
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.longhorn.io";
    chart = "longhorn";
    version = "1.8.1";
    chartHash = "sha256-tRepKwXa0GS4/vsQQrs5DQ/HMzhsoXeiUsXh6+sSMhw=";
  };

  uses-ingress = true;

  defaultValues = cfg: {
    defaultSettings.defaultReplicaCount = 1;

    ingress = with cfg.ingress; {
      inherit ingressClassName;
      enabled = true;
      host = domain;
      tls = tls.enable;
    };

    longhornUI.replicas = 1;

    persistence = {
      defaultClass = false;
      defaultClassReplicaCount = 1;
    };

    preUpgradeChecker.jobEnabled = false;
  };
}
