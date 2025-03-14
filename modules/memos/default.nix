{ config, lib, ... }:
let
  cfg = config.services.memos;

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.gabe565.com";
    chart = "memos";
    version = "0.15.1";
    chartHash = "sha256-k9UU0fLgFgn/aogTD+PMxcQOnZ9g47vFXeyhnf2hqbQ=";
  };

  defaultNamespace = "memos";
  domain = "memos.dev.kronkltd.net";

  # https://artifacthub.io/packages/helm/gabe565/memos?modal=values
  defaultValues = {
    ingress.main = {
      enabled = true;
      hosts = [{
        host = domain;
        paths = [{ path = "/"; }];
      }];
      tls = [{
        secretName = "memo-tls";
        hosts = [ domain ];
      }];
    };
    persistence.data.enabled = false;
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
    applications.memos = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.memos = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
