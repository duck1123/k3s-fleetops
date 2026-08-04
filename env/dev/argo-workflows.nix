{ config, ... }:
{
  services.argo-workflows = {
    enable = false;

    ingress = {
      domain = "argo-workflows.${config.devDefaults.baseDomain}";
      ingressClassName = "traefik";
    };
  };
}
