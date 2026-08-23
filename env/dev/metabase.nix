{ config, ... }:
{
  services.metabase = {
    enable = false;

    ingressProvider = "traefik-lan";
  };
}
