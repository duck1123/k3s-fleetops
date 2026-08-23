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

    serverExternalUrl = "https://affine.${config.devDefaults.tailDomain}";

    ingressProvider = "tailscale";
    ingress.localIngress = {
      enable = true;
      domain = "affine.${config.devDefaults.homeDomain}";
      clusterIssuer = config.devDefaults.clusterIssuer;
      tls.enable = true;
    };

    storageClassName = "longhorn";
  };
}
