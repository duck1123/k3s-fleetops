{ config, ... }:
{
  services.ersatztv = {
    enable = false;
    # logLevel = "Debug";
    hostAffinity = "edgenix";

    ingressProvider = "tailscale";

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/Videos";
    };

    enableGPU = true;
  };
}
