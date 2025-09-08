{ ageRecipients, config, lib, pkgs, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "tailscale";

  # https://tailscale.com/kb/1236/kubernetes-operator
  chart = helm.downloadHelmChart {
    repo = "https://pkgs.tailscale.com/helmcharts";
    chart = "tailscale-operator";
    version = "1.88.2";
    chartHash = "sha256-brC01veNdB36YY1OlDXuoM860or0SiP69uJv7BshuGQ=";
  };

  extraOptions = {
    oauth = {
      # https://tailscale.com/kb/1185/kubernetes
      authKey = mkOption {
        description = mdDoc "The Tailscale auth key";
        type = types.str;
        default = "";
      };

      clientId = mkOption {
        description = mdDoc "The client id";
        type = types.str;
        default = "";
      };

      clientSecret = mkOption {
        description = mdDoc "The client secret";
        type = types.str;
        default = "";
      };
    };
  };

  extraResources = cfg: {
    sopsSecrets = {
      tailscale-auth = createSecret {
        inherit ageRecipients lib pkgs;
        inherit (cfg) namespace;
        secretName = "tailscale-auth";
        values.TS_AUTHKEY = cfg.oauth.authKey;
      };

      operator-oauth = lib.createSecret {
        inherit ageRecipients lib pkgs;
        inherit (cfg) namespace;
        secretName = "operator-oauth";
        values = with cfg.oauth; {
          client_id = clientId;
          client_secret = clientSecret;
        };
      };
    };
  };
}
