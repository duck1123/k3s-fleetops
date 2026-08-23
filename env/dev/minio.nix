{ config, ... }:
{
  services.minio = {
    enable = false;

    ingressProvider = "tailscale";
    ingress = {
      api-domain = "api-minio.${config.devDefaults.tailDomain}";
      tls.enable = true;
    };

    values.defaultBuckets = "my-default-bucket";
  };
}
