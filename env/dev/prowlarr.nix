{ config, secrets, ... }:
{
  services.prowlarr = {
    database = {
      enable = true;
      host = "postgresql.postgresql";
      port = 5432;
      name = "prowlarr-main";
      username = "prowlarr";
      password = secrets.postgresql.userPassword;
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
