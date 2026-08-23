{ config, ... }:
{
  services.uptime-kuma = {
    enable = true;
    storageClassName = "longhorn";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;
  };
}
