{ config, secrets, ... }:
{
  services.qbittorrent = {
    enable = true;
    hostAffinity = "nasnix";

    ingressProvider = "traefik-lan";

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}";
    };

    webui = { inherit (secrets.qbittorrent) password username; };
  };
}
