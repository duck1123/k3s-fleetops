{ secrets, ... }:
{
  services.paperless-ngx = {
    enable = true;

    databaseTarget = "postgresql";

    inherit (secrets.paperless-ngx) adminUser adminPassword;

    # Temporarily scaled to 0 while the PVCs are swapped to their pinned
    # equivalents (see applications/paperless-ngx.nix) -- avoids a live pod
    # holding the old PVCs and blocking their deletion. Revert to 1 once the
    # new pinned PVCs are Bound.
    replicas = 0;

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
