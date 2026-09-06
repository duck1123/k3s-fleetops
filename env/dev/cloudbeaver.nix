{ config, ... }:
{
  services.cloudbeaver = {
    enable = true;
    hostAffinity = "edgenix";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;
    homepage.group = "Database";

    storageClassName = "longhorn";
  };
}
