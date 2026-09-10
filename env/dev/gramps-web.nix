{ secrets, ... }:
{
  services.gramps-web = {
    enable = true;

    redis = {
      host = "redis.redis";
      port = 6379;
      password = secrets.redis.password;
    };

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    # Captured via `kubectl get pv <name> -o jsonpath='{.spec.csi.volumeHandle}'`
    # once this app has been deployed at least once -- see docs/pinned-volumes.md.
    # volumeOverrides = {
    #   users.volumeHandle = "pvc-...";
    #   secret.volumeHandle = "pvc-...";
    #   db.volumeHandle = "pvc-...";
    #   media.volumeHandle = "pvc-...";
    # };
  };
}
