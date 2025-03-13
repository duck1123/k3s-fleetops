{ config, lib, ... }:
let
  cfg = config.services.redis;

  # https://artifacthub.io/packages/helm/bitnami/redis
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "redis";
    version = "20.11.3";
    chartHash = "sha256-GEX81xoTnfMnXY66ih0Ksx5QsXx/3H0L03BnNZQ/7Y4=";
  };

  defaultNamespace = "redis";

  defaultValues = {
    auth = {
      existingSecret = "redis-password";
      existingSecretPasswordKey = "password";
    };

    replicas.replicaCount = 1;
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.redis = {
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
    applications.redis = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.redis = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
