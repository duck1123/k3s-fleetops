{ config, secrets, ... }:
{
  services.nostrarchives = {
    enable = false;

    database = {
      host = "postgresql.postgresql";
      port = 5432;
      name = "nostrarchives";
      username = "nostrarchives";
      password = secrets.postgresql.userPassword;
    };

    redis = {
      host = "redis.redis";
      port = 6379;
      password = secrets.redis.password;
    };

    ingress = {
      domain = "nostrarchives.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
      clusterIssuer = "tailscale";
    };

    relayDomain = "nostrarchives-relay.${config.devDefaults.tailDomain}";
  };
}
