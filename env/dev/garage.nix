{ config, secrets, ... }:
{
  services.garage = {
    enable = true;

    adminToken = (secrets.garage or { }).adminToken or "";
    rpcSecret = (secrets.garage or { }).rpcSecret or "";
    accessKey = (secrets.garage or { }).accessKey or "";
    secretKey = (secrets.garage or { }).secretKey or "";

    ingress = {
      clusterIssuer = config.devDefaults.clusterIssuer;
      domain = "garage.${config.devDefaults.homeDomain}";
      ingressClassName = "traefik";
      tls.enable = true;
    };

    # Start out on longhorn (no NFS) to keep the first boot simple — flip on
    # once garage is validated, pointed at its own NAS export like rustfs's.
    nfs.enable = false;
  };
}
