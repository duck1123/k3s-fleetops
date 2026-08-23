{ config, ... }:
{
  services.fileflows = {
    enable = true;
    hostAffinity = "nixmini";

    ingress = {
      domain = "fileflows.${config.devDefaults.homeDomain}";
      ingressClassName = "traefik";
      clusterIssuer = config.devDefaults.clusterIssuer;
    };

    monitoring.autokuma.enable = true;

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = config.devDefaults.nasBase;
      enableVideos = true;
    };

    puid = 1000;
    pgid = 1000;

    replicas = 1;
    storageClassName = "longhorn";
    useProbes = false;
    enableGPU = true;
  };
}
