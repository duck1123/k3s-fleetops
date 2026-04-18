{ ... }:
{
  flake.nixidyApps.tailscale =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp
      {
        inherit
          config
          lib
          self
          pkgs
          ;
      }
      {
        name = "tailscale";

        sopsSecrets = cfg: {
          tailscale-auth = {
            TS_AUTHKEY = cfg.oauth.authKey;
          };
          operator-oauth = with cfg.oauth; {
            client_id = clientId;
            client_secret = clientSecret;
          };
        };

        # https://tailscale.com/kb/1236/kubernetes-operator
        chart = helm.downloadHelmChart {
          repo = "https://pkgs.tailscale.com/helmcharts";
          chart = "tailscale-operator";
          version = "1.96.5";
          chartHash = "sha256-Dh/fRXdA9z+TMfg7rzfKhKt5cRh6cDYPotP4hXvEpls=";
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

      };
}
