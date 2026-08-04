{ config, ... }:
{
  services.homer = {
    codeserver.ingress = {
      domain = "codeserver.${config.devDefaults.tailDomain}";
      enable = true;
    };

    enable = false;

    ingress = {
      domain = "homer.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
    };
  };
}
