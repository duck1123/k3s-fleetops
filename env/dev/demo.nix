{ config, ... }:
{
  services.demo = {
    enable = false;
    ingressProvider = "tailscale";
  };
}
