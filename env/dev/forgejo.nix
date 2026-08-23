{ config, secrets, ... }:
{
  services.forgejo = {
    admin = { inherit (secrets.forgejo.admin) password username; };
    enable = false;

    ingressProvider = "traefik-lan";
    ingress.localIngress = {
      enable = true;
      domain = "forgejo.${config.devDefaults.homeDomain}";
      clusterIssuer = config.devDefaults.clusterIssuer;
      tls.enable = true;
    };

    monitoring.autokuma.enable = true;

    postgresql = {
      inherit (secrets.forgejo.postgresql)
        adminPassword
        adminUsername
        replicationPassword
        userPassword
        ;
    };

    storageClassName = "longhorn";
  };
}
