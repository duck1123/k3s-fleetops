{ config, secrets, ... }:
{
  services.attic = {
    enable = true;

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    tokenHs256SecretBase64 = secrets.attic.tokenHs256SecretBase64;

    database = {
      host = "postgresql.postgresql";
      port = 5432;
      name = "attic";
      username = "attic";
      password = secrets.postgresql.userPassword;
    };

    storage = {
      bucket = "attic";
      # Use the RustFS S3 API ingress rather than the in-cluster rustfs-svc
      # ClusterIP: atticd generates presigned nar-download URLs against
      # whatever host this is, and rustfs-svc.rustfs is only resolvable
      # from inside the pod network — external pulls (any LAN host, or
      # any nix-csi bootstrap that isn't itself a cluster pod) would 404
      # on DNS. The ingress domain resolves everywhere.
      endpoint = "https://${config.services.rustfs.ingress.api-domain}";
      accessKey = (secrets.rustfs or { }).accessKey or "";
      secretKey = (secrets.rustfs or { }).secretKey or "";
    };
  };
}
