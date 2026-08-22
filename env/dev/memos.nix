{ config, ... }:
{
  services.memos = {
    enable = false;
    hostAffinity = "edgenix";

    databaseTarget = "postgresql";
    database.username = "postgres";

    ingressProvider = "tailscale";
    ingress.localIngress = {
      enable = true;
      domain = "memos.${config.devDefaults.homeDomain}";
      clusterIssuer = config.devDefaults.clusterIssuer;
      tls.enable = true;
    };
  };
}
