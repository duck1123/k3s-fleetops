{ config, ... }:
{
  services.airflow = {
    enable = false;

    ingressProvider = "traefik-dev";
  };
}
