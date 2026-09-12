{ config, ... }:
{
  services.metabase = {
    enable = true;

    ingressProvider = "traefik-lan";
  };
}
