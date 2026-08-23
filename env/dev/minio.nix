{ config, ... }:
{
  services.minio = {
    enable = false;

    ingressProvider = "traefik-lan";
    ingress = {
      api-domain = "api-minio.${config.devDefaults.homeDomain}";
      tls.enable = true;
    };

    values.defaultBuckets = "my-default-bucket";
  };
}
