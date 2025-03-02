{ charts, config, lib, ... }:
let
  cfg = config.services.memos;

  chartConfig = {
    repo = "https://charts.gabe565.com";
    chart = "memos";
    version = "0.15.1";
    chartHash = "sha256-k9UU0fLgFgn/aogTD+PMxcQOnZ9g47vFXeyhnf2hqbQ=";
  };

  defaultNamespace = "memos";
  domain = "memos.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  # https://artifacthub.io/packages/helm/gabe565/memos?modal=values
  defaultValues = {
    ingress.main = {
      enabled = true;
      hosts = [{
        host = "memos.dev.kronkltd.net";
        paths = [{ path = "/"; }];
      }];
      tls = [{
        secretName = "memo-tls";
        hosts = [ "memos.dev.kronkltd.net" ];
      }];
    };
    persistence.data.enabled = true;
    postgresql = {
      enabled = true;
      primary.persistence.enabled = false;
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.memos = {
    enable = mkEnableOption "Enable application";
    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = defaultNamespace;
    };

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    applications.memos = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.memos = { inherit chart values; };
    };
  };
}
