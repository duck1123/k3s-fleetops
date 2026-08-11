{ config, secrets, ... }:
{
  services.rustfs = {
    accessKey = (secrets.rustfs or { }).accessKey or "";
    enable = true;
    hostAffinity = "nasnix";

    ingress = {
      api-domain = "api-rustfs.${config.devDefaults.homeDomain}";
      clusterIssuer = config.devDefaults.clusterIssuer;
      domain = "rustfs.${config.devDefaults.homeDomain}";
      ingressClassName = "traefik";
      tls.enable = true;
    };

    mode = "standalone";

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/LonghornBackups";
    };

    secretKey = (secrets.rustfs or { }).secretKey or "";
  };
}
