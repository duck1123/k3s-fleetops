{ config, ... }:
{
  services.mindsdb = {
    enable = false;

    ingress = {
      domain = "mindsdb.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
    };
  };
}
