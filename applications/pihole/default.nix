{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  password-secret = "admin-password";
in
mkArgoApp { inherit config lib; } {
  name = "pihole";

  # https://artifacthub.io/packages/helm/mojo2600/pihole
  chart = lib.helm.downloadHelmChart {
    repo = "https://mojo2600.github.io/pihole-kubernetes/";
    chart = "pihole";
    version = "2.34.0";
    chartHash = "sha256-nhvifpDdM8MoxF43cJAi6o+il2BbHX+udVAvvm1PukM=";
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

  defaultValues =
    cfg: with cfg; {
      admin = {
        enabled = true;
        existingSecret = password-secret;
      };

      ingress = with cfg.ingress; {
        inherit ingressClassName;

        enabled = enable;
        hosts = [ domain ];
        tls = [
          {
            secretName = "pihole-tls";
            hosts = [ domain ];
          }
        ];
      };

      persistence = { inherit (cfg) storageClass; };
      pihole = { inherit (cfg) timezone; };
      webui.admin = { inherit (cfg.auth) email password; };
    };

  extraResources = cfg: {
    sopsSecrets.${password-secret} = lib.createSecret {
      inherit lib pkgs;
      inherit (config) ageRecipients;
      inherit (cfg) namespace;
      inherit (self.lib) encryptString toYAML;
      secretName = password-secret;
      values = with cfg; {
        inherit (auth) password;
      };
    };
  };
}
