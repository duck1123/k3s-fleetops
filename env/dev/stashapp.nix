{ config, secrets, ... }:
{
  services.stashapp = {
    enable = true;
    apiKey = secrets.stashapp.key;
    hostAffinity = "nixmini";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/Videos";
    };

    replicas = 1;
    enableGPU = true;
  };
}
