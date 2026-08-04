{ config, ... }:
{
  services.demo = {
    enable = false;
    ingress = {
      domain = "demo.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
      clusterIssuer = "tailscale";
    };
  };
}
