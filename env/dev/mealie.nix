{ config, secrets, ... }:
{
  services.mealie = {
    enable = false;
    # hostAffinity = "edgenix";
    image = "ghcr.io/mealie-recipes/mealie:v3.22.0";

    database = {
      enable = true;
      host = "postgresql.postgresql";
      name = "mealie";
      username = "mealie";
      password = secrets.mealie.databasePassword;
    };

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    storageClassName = "longhorn";
  };
}
