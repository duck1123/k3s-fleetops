{ config, ... }:
{
  services.sabnzbd = {
    enable = true;
    hostAffinity = "edgenix";

    ingress = {
      clusterIssuer = config.devDefaults.clusterIssuer;
      domain = "sabnzbd.${config.devDefaults.homeDomain}";
      ingressClassName = "traefik";
      tls.enable = true;
    };

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}";
    };

    replicas = 1;
    useProbes = false;
  };
}
