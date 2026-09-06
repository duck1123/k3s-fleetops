{ config, secrets, ... }:
{
  services.prowlarr = {
    databaseTarget = "postgresql";
    database = {
      enable = true;
      name = "prowlarr-main";
    };

    enable = true;
    apiKey = secrets.prowlarr.key;
    hostAffinity = "edgenix";
    image = "linuxserver/prowlarr:2.5.2.5491-ls156";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;
    homepage.group = "Arr";

    replicas = 1;
    vpn.enable = false;
  };
}
