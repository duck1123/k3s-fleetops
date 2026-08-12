{ config, ... }:
{
  services.stashapp = {
    enable = true;
    hostAffinity = "nixmini";

    ingress = {
      clusterIssuer = config.devDefaults.clusterIssuer;
      domain = "stashapp.${config.devDefaults.homeDomain}";
      ingressClassName = "traefik";
      tls.enable = true;
    };

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = "${config.devDefaults.nasBase}/Videos";
    };

    replicas = 0; # TEMPORARY: paused for data-recovery investigation on pvc-9d446279 (corrupted replica, see incident notes). Restore to 1 once resolved.
    enableGPU = true;
  };
}
