{ config, ... }:
{
  services.airflow = {
    enable = false;

    ingress = {
      inherit (config.devDefaults) clusterIssuer;
      domain = "airflow.${config.devDefaults.baseDomain}";
    };
  };
}
