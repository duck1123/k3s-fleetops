{ config, ... }:
{
  services.cloudbeaver = {
    enable = true;
    hostAffinity = "edgenix";

    ingress = {
      clusterIssuer = config.devDefaults.clusterIssuer;
      domain = "cloudbeaver.${config.devDefaults.homeDomain}";
      ingressClassName = "traefik";
      tls.enable = true;
    };

    storageClassName = "longhorn";
  };
}
