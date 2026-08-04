{ config, ... }:
{
  services.ersatztv = {
    enable = false;
    # logLevel = "Debug";
    hostAffinity = "edgenix";

    ingress = {
      domain = "ersatztv.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
      clusterIssuer = "tailscale";
    };

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/Videos";
    };

    enableGPU = true;
  };
}
