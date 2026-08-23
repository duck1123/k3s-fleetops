{ config, ... }:
{
  services.specter = {
    enable = false;

    ingressProvider = "tailscale";

    namespace = "specter";
  };
}
