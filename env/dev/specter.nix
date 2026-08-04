{ config, ... }:
{
  services.specter = {
    enable = false;

    ingress = {
      domain = "specter.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
    };

    namespace = "specter";
  };
}
