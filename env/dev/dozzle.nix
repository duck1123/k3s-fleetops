{ config, ... }:
{
  services.dozzle = {
    enable = false;
    hostAffinity = "nasnix";

    ingress = {
      domain = "dozzle.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
      clusterIssuer = "tailscale";
    };
  };
}
