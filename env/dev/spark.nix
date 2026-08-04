{ config, ... }:
{
  services.spark = {
    enable = false;

    ingress = {
      domain = "spark.${config.devDefaults.tailDomain}";
      ingressClassName = "tailscale";
      clusterIssuer = "tailscale";
    };
  };
}
