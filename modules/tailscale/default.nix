{ config, lib, pkgs, ... }:
let
  app-name = "tailscale";
  cfg = config.services.${app-name};

  chart = lib.helm.downloadHelmChart {
    repo = "https://pkgs.tailscale.com/helmcharts";
    chart = "tailscale-operator";
    version = "1.82.0";
    chartHash = "sha256-8b9h+ZAls2FHU6fy4mKn+yR4o/p2BYtSWbaBv5BXjvE=";
  };

  # https://github.com/tailscale/tailscale/blob/main/cmd/k8s-operator/deploy/chart/values.yaml
  values = lib.attrsets.recursiveUpdate { } cfg.values;
in with lib; {
  options.services.${app-name} = {
    enable = mkEnableOption "Enable application";

    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = app-name;
    };

    oauth = {
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

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    applications.${app-name} = {
      inherit (cfg) namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.${app-name} = { inherit chart values; };

      resources.sopsSecrets.operator-oauth = lib.createSecret {
        inherit lib pkgs;
        inherit (cfg) namespace;
        secretName = "operator-oauth";
        values = with cfg.oauth; {
          client_id = clientId;
          client_secret = clientSecret;
        };
      };

      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
