{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
mkArgoApp { inherit config lib; } {
  name = "keycloak";

  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../chart-archives/keycloak-24.1.0.tgz;
    chartName = "keycloak";
  };

  uses-ingress = true;

  extraOptions = {
    ingress = {
      adminDomain = mkOption {
        description = mdDoc "The ingress domain for the admin";
        type = types.str;
        default = defaultApiDomain;
      };
    };
  };

  defaultValues = cfg: {
    auth = {
      adminUser = "admin";
      existingSecret = "keycloak-admin-password";
      passwordSecretKey = "password";
    };

    ingress = with cfg.ingress; {
      enabled = true;
      ingressClassName = "traefik";
      hostname = domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      tls = true;
    };

    adminIngress = with cfg.ingress; {
      enabled = true;
      ingressClassName = "traefik";
      hostname = adminDomain;
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      tls = true;
    };
  };

  extraResources = cfg: {
    sealedSecrets.keycloak-admin-password.spec = {
      encryptedData.password = "AgBMtaSD0NBt9kb50YJtd/KkzCvM7m/WDuQ2FxcipwPGmAu/HB3ThieIfH1NHk0+EasS/j1C972GiA72VE450b+7TOXZbkjJXejBOmN+tIFc8oXpfrceCSQxkn3vGL6nBYzuAeHKX3d3s6y1pyYMD90lccqd1mMBfLeve/r+RAsXiWCFiHZh0DVVo13pGBYy77p2SR6ZTSXoVjkehE5wnSjUh70M3RCavI6sMjc+ZpVRoJccQ9YPQV3xT6qEPkKJRl//Gv9k7Ve66VvrVSW7hixdNQK/094m2mzjfaa1KxNWfO8LV2tMfBY0eC1HEpLlmxnMNCGWcnzcBgXUKOKEH+zavvSouoiCwj+NtdRWB3Ky5dqs2LtW3Lv8ElLwCRn1DN1/F7I930aYeI8mkxmvxmKRObkd3RNqA/ZiwqAMWH9hpJMaG8//IYQJXzPEa2HOdw+XaoeY/53LC5UzjCrQQeGoRjS85Zpv4XnjqkdBXQ2rwQ/DmKpoYTHxWpXopxbuTii/xsPWO+2oQ1OTdipungglH4OcXLMaXaZqebsz21vZN/qf1Vi+T3qwycRnDd9BCRvgL/OzugUvV4iqVsI2CdHMILwyORPi6drEssnLh7tin2kDRWAWB6S9Di361EzBX0oUzTYuR/imvD+RPPKlN4h+AY5rxh5t+hYfPLKJSgQFWctYas8nertS6Dyh01wiw6lc4RpbSogrArFAJb3/3/LV/aHKZg==";
      template.metadata = {
        inherit (cfg) namespace;
        name = "keycloak-admin-password";
      };
    };
  };
}
