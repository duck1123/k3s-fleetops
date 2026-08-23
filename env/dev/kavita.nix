{ config, ... }:
{
  services.kavita = {
    enable = false;

    ingressProvider = "tailscale";
    ingress.tls.enable = true;
  };
}
