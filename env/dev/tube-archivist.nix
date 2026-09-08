{ config, secrets, ... }:
{
  services.tube-archivist = {
    auth = {
      inherit (secrets.tube-archivist.auth) username password;
    };

    elasticsearch.elasticPassword = secrets.tube-archivist.auth.password;
    # Known upstream bug: https://github.com/tubearchivist/tubearchivist/issues/1209
    # -- re-enabled temporarily to test whether clearing poisoned
    # celery-task-meta-* Redis keys is enough to get past it.
    enable = true;
    hostAffinity = "edgenix";

    ingressProvider = "traefik-lan";

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}";
    };

    redis = {
      host = "redis.redis";
      port = 6379;
      password = secrets.redis.password;
    };
    storageClassName = "longhorn";
    replicas = 1;
  };
}
