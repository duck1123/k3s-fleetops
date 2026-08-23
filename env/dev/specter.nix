{ config, ... }:
{
  services.specter = {
    enable = false;

    ingressProvider = "traefik-lan";

    namespace = "specter";
  };
}
