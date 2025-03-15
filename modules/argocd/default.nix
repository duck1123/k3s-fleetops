{ config, lib, ... }:
let
  cfg = config.services.argocd;
  defaultNamespace = "argocd";
  namespace = cfg.namespace;
in with lib; {
  options.services.argocd = {
    enable = mkEnableOption "Enable application";
    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = defaultNamespace;
    };
  };

  config = mkIf cfg.enable {
    applications.argocd = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      resources = {
        configMaps.argocd-cm.data = {
          "exec.enabled" = "true";
          "exec.shells" = "bash,sh";
          "kustomize.buildOptions" = "--enable-helm";
          "ui.bannercontent" = "Ignore This Notice!";
          "ui.bannerurl" = "https://duck1123.com/";
          "url" = "https://argocd.dev.kronkltd.net";
        };
        secrets = {
          bitnamicharts = {
            metadata.labels."argocd.argoproj.io/secret-type" = "repository";
            stringData = {
              enableOCI = "true";
              name= "bitnamicharts";
              type = "helm";
              url = "registry-1.docker.io/bitnamicharts";
            };
          };
          forgejo-helm-oci = {
            metadata.labels."argocd.argoproj.io/secret-type" = "repository";
            stringData = {
              enableOCI = "true";
              name= "forgejo-helm";
              type = "helm";
              url = "registry-1.docker.io/bitnamicharts";
            };
          };
        };
      };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
