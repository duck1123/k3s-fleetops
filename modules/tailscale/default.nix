{ ageRecipients, config, lib, pkgs, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "tailscale";

  chart = helm.downloadHelmChart {
    repo = "https://pkgs.tailscale.com/helmcharts";
    chart = "tailscale-operator";
    version = "1.82.0";
    chartHash = "sha256-8b9h+ZAls2FHU6fy4mKn+yR4o/p2BYtSWbaBv5BXjvE=";
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
        values = with cfg.oauth; { TS_AUTHKEY = authKey; };
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
