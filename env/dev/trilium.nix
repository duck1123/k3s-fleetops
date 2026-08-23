{ config, ... }:
{
  services.trilium = {
    enable = true;

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    storageClassName = "longhorn";
  };
}
