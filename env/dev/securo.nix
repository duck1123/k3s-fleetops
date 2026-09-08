{ secrets, ... }:
{
  services.securo = {
    enable = true;

    databaseTarget = "postgresql";

    secretKey = secrets.securo.secretKey;

    redis = {
      host = "redis.redis";
      port = 6379;
      password = secrets.redis.password;
    };

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;
    homepage.group = "Finance";

    storageClassName = "longhorn";
  };
}
