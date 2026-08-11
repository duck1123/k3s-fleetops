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

    # Matches duck's NAS account uid/gid so NFS writes are actually authorized
    # server-side (the NFS export's "no mapping" squash passes the client uid
    # through as-is — it doesn't grant access on its own).
    uid = 1000;

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/RustFS";
    };

    secretKey = (secrets.rustfs or { }).secretKey or "";
  };
}
