{ config, ... }:
{
  services.tunarr = {
    enable = false;
    enableGPU = true;
    hostAffinity = "edgenix";
    resetDatabase = false;

    ingress = {
      domain = "tunarr.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
      clusterIssuer = "tailscale";
    };

    nfs = {
      enable = false;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}";

      config = {
        enable = false;
        path = "${config.devDefaults.nasBase}/tunarr";
      };
    };

    replicas = 1;
    storageClassName = "local-path";
  };
}
