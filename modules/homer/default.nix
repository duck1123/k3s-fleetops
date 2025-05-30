{ config, lib, ... }:
let
  cfg = config.services.homer;

  # https://artifacthub.io/packages/helm/gabe565/homer
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.gabe565.com";
    chart = "homer";
    version = "0.13.0";
    chartHash = "sha256-z6o5LHUYqm7Jd5gsIs+J3Z48Frbj8F1ZnEZw4mHIeQA=";
  };

  defaultNamespace = "homer";
  homerDomain = "homer.dev.kronkltd.net";
  codeserverDomain = "codeserver.dev.kronkltd.net";

  defaultValues = {
    ingress = {
      main = {
        enabled = true;
        hosts = [{
          host = homerDomain;
          paths = [{ path = "/"; }];
        }];
        tls = [{
          secretName = "homer-tls";
          hosts = [ homerDomain ];
        }];
      };

      addons.codeserver = {
        enabled = true;
        ingress = {
          enabled = true;
          hosts = [{
            host = codeserverDomain;
            paths = [{ path = "/"; }];
          }];
          tls = [{
            secretName = "codeserver-tls";
            hosts = [ codeserverDomain ];
          }];
        };
      };
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.homer = {
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
    applications.homer = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.homer = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
