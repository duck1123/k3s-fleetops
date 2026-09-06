{ config, secrets, ... }:
{
  services.trilium = {
    enable = true;
    apiKey = secrets.trilium.key;

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;
    homepage.group = "Notes";

    storageClassName = "longhorn";
  };
}
