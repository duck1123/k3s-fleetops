{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib;
mkArgoApp { inherit config lib; } {
  name = "tailscale";

  # https://tailscale.com/kb/1236/kubernetes-operator
  chart = helm.downloadHelmChart {
    repo = "https://pkgs.tailscale.com/helmcharts";
    chart = "tailscale-operator";
    version = "1.92.4";
    chartHash = "sha256-uFzbD6qJqgxwAR7v4+t1fd89S7dyugnFWBlpA8MgtHE=";
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
        inherit lib pkgs;
        inherit (config) ageRecipients;
        inherit (cfg) namespace;
        inherit (self.lib) toYAML;
        secretName = "tailscale-auth";
        values.TS_AUTHKEY = cfg.oauth.authKey;
      };

      operator-oauth = lib.createSecret {
        inherit lib pkgs;
        inherit (config) ageRecipients;
        inherit (cfg) namespace;
        inherit (self.lib) toYAML;
        secretName = "operator-oauth";
        values = with cfg.oauth; {
          client_id = clientId;
          client_secret = clientSecret;
        };
      };
    };
  };
}
