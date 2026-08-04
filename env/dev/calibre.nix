{ config, ... }:
{
  services.calibre = {
    enable = false;

    ingress = {
      domain = "calibre.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
      clusterIssuer = "tailscale";
    };

    storageClassName = "longhorn";
  };
}
