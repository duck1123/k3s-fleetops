{ config, ... }:
{
  services.dozzle = {
    enable = false;
    hostAffinity = "nasnix";

    ingressProvider = "tailscale";
  };
}
