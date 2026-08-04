{ config, secrets, ... }:
{
  services.pihole = {
    auth = { inherit (secrets.pihole) email password; };
    enable = true;
    hostAffinity = "nasnix";

    ingress = {
      clusterIssuer = config.devDefaults.clusterIssuer;
      domain = "pihole.${config.devDefaults.homeDomain}";
      ingressClassName = "traefik";
      tls.enable = true;
    };
    serviceDnsLoadBalancerIP = "192.168.0.243";
    storageClassName = "longhorn";
    customDnsEntries = [
      "address=/.dev.kronkltd.net/192.168.0.242"
      "address=/.home.kronkltd.net/192.168.0.242"
    ];
  };
}
