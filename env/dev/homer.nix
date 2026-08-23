{ config, ... }:
{
  services.homer = {
    codeserver.ingress = {
      domain = "codeserver.${config.devDefaults.tailDomain}";
      enable = true;
    };

    enable = false;

    ingressProvider = "tailscale";
  };
}
