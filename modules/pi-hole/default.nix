{ config, lib, pkgs, ... }:
let
  app-name = "pihole";
  cfg = config.services.${app-name};

  chart = lib.helm.downloadHelmChart {
    repo = "https://savepointsam.github.io/charts";
    chart = "pihole";
    version = "0.2.0";
    chartHash = "sha256-jwqcjoQXi41Y24t4uGqnw6JVhB2bBbiv5MasRTbq3hA=";
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

      # resources.sopsSecrets = {
      #   tailscale-auth = lib.createSecret {
      #     inherit lib pkgs;
      #     inherit (cfg) namespace;
      #     secretName = "tailscale-auth";
      #     values = with cfg.oauth; {
      #       TS_AUTHKEY = authKey;
      #     };
      #   };

      #   operator-oauth = lib.createSecret {
      #     inherit lib pkgs;
      #     inherit (cfg) namespace;
      #     secretName = "operator-oauth";
      #     values = with cfg.oauth; {
      #       client_id = clientId;
      #       client_secret = clientSecret;
      #     };
      #   };
      # };

      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
