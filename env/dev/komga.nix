{ config, ... }:
{
  services.komga = {
    enable = true;

    ingress = {
      domain = "komga.${config.devDefaults.homeDomain}";
      clusterIssuer = config.devDefaults.clusterIssuer;
      ingressClassName = "traefik";
      tls.enable = true;
    };

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/Books";
    };
  };
}
