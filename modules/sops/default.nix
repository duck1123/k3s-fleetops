{ config, lib, ... }:
let
  app-name = "sops";
  cfg = config.services.${app-name};

  # https://artifacthub.io/packages/helm/bitnami/redis
  chart = lib.helm.downloadHelmChart {
    repo = "https://isindir.github.io/sops-secrets-operator/";
    chart = "sops-secrets-operator";
    version = "0.21.0";
    chartHash = "sha256-SmSp9oo8ue9DuRQSHevJSrGVVB5xmmlook53Y8AfUZY=";
  };

  defaultNamespace = app-name;

  defaultValues = { };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
in with lib; {
  options.services.${app-name} = {
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
    applications.${app-name} = {
      inherit (cfg) namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.${app-name} = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };

    nixidy.resourceImports = [ ./generated.nix ];
  };
}
