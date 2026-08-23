{ config, ... }:
{
  services.calibre = {
    enable = false;

    ingressProvider = "tailscale";

    storageClassName = "longhorn";
  };
}
