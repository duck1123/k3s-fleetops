{ config, lib, ... }:
let
  cfg = config.services.airflow;

  chart = lib.helm.downloadHelmChart {
    repo = "https://airflow.apache.org";
    chart = "airflow";
    version = "1.15.0";
    chartHash = "sha256-sYiZkYjnBqmhe/4vISvUXUQx2r+XHAd9bhWGrkn4tKM=";
  };

  defaultNamespace = "airflow";
  domain = "airflow.dev.kronkltd.net";
  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    createUserJob = {
      applyCustomEnv = false;
      useHelmHooks = false;
    };

    ingress.web = {
      annotations = { "cert-manager.io/cluster-issuer" = clusterIssuer; };
      enabled = true;
      hosts = [{
        name = domain;
        tls = {
          enabled = true;
          secretName = "airflow-tls";
        };
      }];
    };

    migrateDatabaseJob = {
      applyCustomEnv = false;
      useHelmHooks = false;
    };

  };
  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.airflow = {
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
    applications.airflow = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.airflow = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
