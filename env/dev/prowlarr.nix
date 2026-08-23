{ config, ... }:
{
  services.prowlarr = {
    databaseTarget = "postgresql";
    database = {
      enable = true;
      name = "prowlarr-main";
    };

    enable = true;
    hostAffinity = "edgenix";
    image = "linuxserver/prowlarr:2.5.2.5491-ls156";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    replicas = 1;
    vpn.enable = false;
  };
}
