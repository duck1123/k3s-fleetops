{ config, lib, pkgs, ... }:
let
  app-name = "tailscale";
  cfg = config.services.${app-name};

  # https://github.com/tailscale/tailscale/blob/main/cmd/k8s-operator/deploy/chart/values.yaml
  values = lib.attrsets.recursiveUpdate { } cfg.values;
in with lib; {
  options.services.${app-name} = {
    chart = mkOption {
      type = types.path;
      default = lib.helm.downloadHelmChart {
        repo = "https://pkgs.tailscale.com/helmcharts";
        chart = "tailscale-operator";
        version = "1.82.0";
        chartHash = "sha256-8b9h+ZAls2FHU6fy4mKn+yR4o/p2BYtSWbaBv5BXjvE=";
      };
      description = ''
        Optional Helm chart derivation to use for deploying this app.
        Should point to a path produced by something like `lib.helm.downloadHelmChart`.
      '';
    };

    enable = mkEnableOption "Enable application";

    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = app-name;
    };

    neededSecrets = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of required secret keys (names, no paths).";
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
      helm.releases.${app-name} = {
        inherit values;
        inherit (cfg) chart;
      };

      resources.sopsSecrets = {
        tailscale-auth = lib.createSecret {
          inherit lib pkgs;
          inherit (cfg) namespace;
          secretName = "tailscale-auth";
          values = with cfg.oauth; { TS_AUTHKEY = authKey; };
        };

        operator-oauth = lib.createSecret {
          inherit lib pkgs;
          inherit (cfg) namespace;
          secretName = "operator-oauth";
          values = with cfg.oauth; {
            client_id = clientId;
            client_secret = clientSecret;
          };
        };
      };

      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
