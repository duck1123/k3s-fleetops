{ config, ... }:
{
  services.mindsdb = {
    enable = false;

    ingressProvider = "tailscale";
  };
}
