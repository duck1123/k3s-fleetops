{ config, secrets, ... }:
{
  services.komga = {
    enable = true;
    apiKey = secrets.komga.key;

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;
    homepage.group = "Media";

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/Books";
    };
  };
}
