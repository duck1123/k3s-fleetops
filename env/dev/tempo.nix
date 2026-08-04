{ config, ... }:
{
  services.tempo = {
    enable = false;
    ingress = {
      inherit (config.devDefaults) clusterIssuer;
      domain = "tempo.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
    };
  };
}
