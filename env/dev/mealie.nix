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

    ingress = {
      domain = "mealie.${config.devDefaults.homeDomain}";
      ingressClassName = "traefik";
      clusterIssuer = config.devDefaults.clusterIssuer;
      tls.enable = true;
    };

    storageClassName = "longhorn";
  };
}
