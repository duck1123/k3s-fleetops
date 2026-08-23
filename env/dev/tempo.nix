{ config, ... }:
{
  services.tempo = {
    enable = false;
    ingressProvider = "tailscale";
  };
}
