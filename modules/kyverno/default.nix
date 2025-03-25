{ config, lib, ... }:
let
  cfg = config.services.kyverno;

  chart = lib.helm.downloadHelmChart {
    repo = "https://kyverno.github.io/kyverno/";
    chart = "kyverno";
    version = "3.4.0-alpha.1";
    chartHash = "sha256-rYlJrh8h1oiq7zRxLqEuFW2Kxst90iFAyEDUJes84x0=";
  };

  defaultNamespace = "kyverno";

  defaultValues = { };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.kyverno = {
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
    applications.kyverno = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.kyverno = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
