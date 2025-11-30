{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib;
self.lib.mkArgoApp { inherit config lib; } {
  name = "tailscale";

  # https://tailscale.com/kb/1236/kubernetes-operator
  chart = helm.downloadHelmChart {
    repo = "https://pkgs.tailscale.com/helmcharts";
    chart = "tailscale-operator";
    version = "1.92.4";
    chartHash = "sha256-uFzbD6qJqgxwAR7v4+t1fd89S7dyugnFWBlpA8MgtHE=";
  };

  extraOptions = {
    loginServer = mkOption {
      description = mdDoc "The Tailscale login server (e.g., headscale server URL). Leave empty to use Tailscale's default coordination server.";
      type = types.nullOr types.str;
      default = null;
    };

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

  defaultValues = cfg:
    lib.optionalAttrs (cfg.loginServer != null) {
      operator = {
        env = {
          OPERATOR_LOGIN_SERVER = cfg.loginServer;
        };
      };
    };

  extraResources = cfg: {
    sopsSecrets = {
      tailscale-auth = self.lib.createSecret {
        inherit lib pkgs;
        inherit (config) ageRecipients;
        inherit (cfg) namespace;
        secretName = "tailscale-auth";
        values.TS_AUTHKEY = cfg.oauth.authKey;
      };

      operator-oauth = self.lib.createSecret {
        inherit lib pkgs;
        inherit (config) ageRecipients;
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
