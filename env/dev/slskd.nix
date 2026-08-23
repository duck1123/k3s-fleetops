{ config, secrets, ... }:
{
  services.slskd = {
    apiKey = (secrets.slskd or { }).apiKey or "";
    enable = true;
    # hostAffinity = "edgenix";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/slskd_downloads";
    };

    replicas = 1;

    shares = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/Music";
    };

    storageClassName = "longhorn";
    useProbes = false;

    vpn = {
      enable = true;
      sharedGluetunService = "gluetun.gluetun";
    };

    webAuth = {
      username = (secrets.slskd or { }).username or "";
      password = (secrets.slskd or { }).password or "";
    };
  };
}
