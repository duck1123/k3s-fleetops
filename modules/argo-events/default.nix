{ charts, config, lib, ... }:
let
  cfg = config.services.argo-events;

  # https://artifacthub.io/packages/helm/argo/argo-events
  chart = lib.helm.downloadHelmChart {
    repo = "https://argoproj.github.io/argo-helm";
    chart = "argo-events";
    version = "2.4.14";
    chartHash = "sha256-gLZOCMLYd9lSQfOQKqgYVscsDcsOTc1v25FvY0P95W4=";
  };

  defaultNamespace = "argo-events";

  defaultValues = { metrics.enabled = true; };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.argo-events = {
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
    applications.argo-events = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.argo-events = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
