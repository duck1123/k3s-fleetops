{ ... }:
{
  services.sonarr = {
    databaseTarget = "postgresql";
    database.enable = true;

    enable = true;
    image = "linuxserver/sonarr:4.0.19.2979-ls321";
    hostAffinity = "edgenix";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    nfsTarget = "nas";
    nfs.enable = true;

    replicas = 1;
    vpn.enable = false;
  };
}
