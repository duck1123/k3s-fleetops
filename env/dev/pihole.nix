{ config, secrets, ... }:
{
  services.pihole = {
    auth = { inherit (secrets.pihole) email password; };
    enable = true;
    hostAffinity = "nasnix";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;
    serviceDnsLoadBalancerIP = "192.168.0.243";
    storageClassName = "longhorn";
    customDnsEntries = [
      "address=/.dev.kronkltd.net/192.168.0.242"
      "address=/.home.kronkltd.net/192.168.0.242"
    ];
  };
}
