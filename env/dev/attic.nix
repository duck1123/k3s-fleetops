{ config, secrets, ... }:
{
  services.attic = {
    enable = true;

    ingress = {
      domain = "attic.${config.devDefaults.homeDomain}";
      ingressClassName = "traefik";
      clusterIssuer = config.devDefaults.clusterIssuer;
      tls.enable = true;
    };

    tokenHs256SecretBase64 = secrets.attic.tokenHs256SecretBase64;

    database = {
      host = "postgresql.postgresql";
      port = 5432;
      name = "attic";
      username = "attic";
      password = secrets.postgresql.userPassword;
    };

    storage = {
      bucket = "attic";
      accessKey = (secrets.rustfs or { }).accessKey or "";
      secretKey = (secrets.rustfs or { }).secretKey or "";
    };
  };
}
