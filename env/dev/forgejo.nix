{ secrets, ... }:
{
  services.forgejo = {
    admin = { inherit (secrets.forgejo.admin) password username; };
    enable = false;
    ingressProvider = "traefik-lan";
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
