{ secrets, ... }:
{
  services.paperless-ngx = {
    enable = true;

    databaseTarget = "postgresql";

    inherit (secrets.paperless-ngx) adminUser adminPassword secretKey;

    redis = {
      host = "redis.redis";
      port = 6379;
      password = secrets.redis.password;
    };

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    storageClassName = "longhorn";
  };
}
