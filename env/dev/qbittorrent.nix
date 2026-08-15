{ config, secrets, ... }:
{
  services.qbittorrent = {
    enable = true;
    hostAffinity = "nasnix";

    ingress = {
      domain = "qbittorrent.${config.devDefaults.homeDomain}";
      ingressClassName = "traefik";
      clusterIssuer = config.devDefaults.clusterIssuer;
    };

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}";
    };

    webui = { inherit (secrets.qbittorrent) password username; };
  };
}
