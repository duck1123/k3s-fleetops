{ config, ... }:
{
  services.metabase = {
    enable = false;

    ingressProvider = "tailscale";
  };
}
