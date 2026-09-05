{ config, secrets, ... }:
{
  services.affine = {
    enable = false;
    # hostAffinity = "edgenix";

    databaseTarget = "postgresql";

    redis = {
      host = "redis.redis";
      port = 6379;
      password = secrets.redis.password;
    };

    serverExternalUrl = "https://affine.${config.devDefaults.homeDomain}";

    ingressProvider = "traefik-lan";

    storageClassName = "longhorn";
  };
}
