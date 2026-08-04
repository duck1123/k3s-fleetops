{ config, ... }:
{
  services.kavita = {
    enable = false;

    ingress = {
      domain = "kavita.${config.devDefaults.tailDomain}";
      clusterIssuer = "tailscale";
      ingressClassName = "tailscale";
      tls.enable = true;
    };
  };
}
