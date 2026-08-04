{ config, secrets, ... }:
{
  services.authentik = {
    inherit (secrets.authentik) secret-key;
    enable = false;

    ingress = {
      inherit (config.devDefaults) clusterIssuer;
      domain = "authentik.${config.devDefaults.baseDomain}";
      ingressClassName = "traefik";
    };

    postgresql = {
      inherit (secrets.authentik.postgresql)
        password
        postgres-password
        replicationPassword
        ;
      host = "postgreql.postgreql";
    };
  };
}
