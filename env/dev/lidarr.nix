{ config, secrets, ... }:
{
  services.lidarr = {
    database = {
      enable = true;
      host = "postgresql.postgresql";
      port = 5432;
      name = "lidarr";
      username = "lidarr";
      password = secrets.postgresql.userPassword;
    };

    enable = true;
    hostAffinity = "edgenix";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    monitoring.autokuma.enable = true;

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}";

      slskdDownloads = {
        enable = true;
        path = "${config.devDefaults.nasBase}/slskd_downloads";
      };
    };

    replicas = 1;
    storageClassName = "longhorn";

    vpn = {
      enable = false;
      sharedGluetunService = "gluetun.gluetun";
    };
  };
}
