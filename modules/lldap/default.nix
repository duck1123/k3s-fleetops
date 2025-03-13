{ config, lib, ... }:
let
  cfg = config.services.lldap;

  chart = lib.helm.downloadHelmChart {
    repo = "https://djjudas21.github.io/charts/";
    chart = "lldap";
    version = "0.4.2";
    chartHash = "sha256-YwInTAIEIpWS/Sd4Kb4ABsH2rYGg/zcpTQGoJW8wbSQ=";
  };

  defaultNamespace = "lldap";

  # https://artifacthub.io/packages/helm/djjudas21/lldap?modal=values
  defaultValues = { lldap.baseDN = "dc=kronkltd,dc=net"; };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.lldap = {
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
    applications.lldap = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.lldap = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
