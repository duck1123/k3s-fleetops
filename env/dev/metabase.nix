{ config, ... }:
{
  services.metabase = {
    enable = false;

    ingress = {
      domain = "metabase.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
    };
  };
}
