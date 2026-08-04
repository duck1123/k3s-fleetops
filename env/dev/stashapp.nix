{ config, ... }:
{
  services.stashapp = {
    enable = true;
    hostAffinity = "nixmini";

    ingress = {
      clusterIssuer = config.devDefaults.clusterIssuer;
      domain = "stashapp.${config.devDefaults.homeDomain}";
      ingressClassName = "traefik";
      tls.enable = true;
    };

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/Videos";
    };

    replicas = 1;
    enableGPU = true;
  };
}
