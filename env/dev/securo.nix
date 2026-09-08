{ secrets, ... }:
{
  services.securo = {
    enable = true;

    databaseTarget = "postgresql";

    # Alembic's `config.set_main_option("sqlalchemy.url", ...)` runs the URL
    # through Python's ConfigParser, which treats "%" as interpolation
    # syntax -- any percent-encoded special character in the shared
    # databaseProviders.postgresql password (e.g. `)`, `:`, `+`) crashes
    # migrations with "invalid interpolation syntax". Give securo its own
    # alphanumeric-only password so the DSN never contains a literal "%".
    database.password = secrets.securo.database.password;

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
