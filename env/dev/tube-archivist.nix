{ config, secrets, ... }:
{
  services.tube-archivist = {
    auth = {
      inherit (secrets.tube-archivist.auth) username password;
    };

    elasticsearch.elasticPassword = secrets.tube-archivist.auth.password;
    # Never runs cleanly -- its bundled Celery worker writes task results as
    # pickle, but its own startup cleanup step (ta_startup -> fail_pending)
    # assumes UTF-8/JSON and crashes decoding its own fresh output, causing a
    # permanent CrashLoopBackOff unrelated to ES (which connects fine). Looks
    # like an upstream bug in bbilly1/tubearchivist -- disabled again as it
    # was before, no data worth preserving.
    enable = false;
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
