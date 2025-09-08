{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "pihole";

  # https://artifacthub.io/packages/helm/savepointsam/pihole
  chart = lib.helm.downloadHelmChart {
    repo = "https://savepointsam.github.io/charts";
    chart = "pihole";
    version = "0.2.0";
    chartHash = "sha256-jwqcjoQXi41Y24t4uGqnw6JVhB2bBbiv5MasRTbq3hA=";
  };

  uses-ingress = true;

  extraOptions = {
    auth = {
      email = mkOption {
        description = mdDoc "The admin email";
        type = types.str;
        default = defaultApiDomain;
      };

      password = mkOption {
        description = mdDoc "The password";
        type = types.str;
        default = "CHANGEME";
      };
    };

    storageClass = mkOption {
      description = mdDoc "The storage class for persistence";
      type = types.str;
      default = "longhorn";
    };

    timezone = mkOption {
      description = mdDoc "The time zone";
      type = types.str;
      default = "America/Detroit";
    };
  };

  defaultValues = cfg: {
    persistence = { inherit (cfg) storageClass; };
    pihole = { inherit (cfg) timezone; };
    webui.admin = { inherit (cfg.auth) email password; };
  };
}
