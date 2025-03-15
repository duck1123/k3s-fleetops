{ config, lib, ... }:
let
  cfg = config.services.argocd;
  defaultNamespace = "argocd";
  defaultValues = { };
  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.argocd = {
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
    applications.argocd = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      resources.configMaps.argocd-cm.data = {
        "exec.enabled" = "true";
        "exec.shells" = "bash,sh";
        "kustomize.buildOptions" = "--enable-helm";
        "ui.bannercontent" = "Ignore This Notice!";
        "ui.bannerurl" = "https://duck1123.com/";
        "url" = "https://argocd.dev.kronkltd.net";
      };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
