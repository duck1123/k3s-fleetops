{ config, ... }:
{
  services.minio = {
    enable = false;

    ingress = {
      api-domain = "api-minio.${config.devDefaults.tailDomain}";
      domain = "minio.${config.devDefaults.tailDomain}";
      clusterIssuer = "tailscale";
      ingressClassName = "tailscale";
      tls.enable = true;
    };

    values.defaultBuckets = "my-default-bucket";
  };
}
