{ config, ... }:
{
  services.spark = {
    enable = false;

    ingressProvider = "tailscale";
  };
}
