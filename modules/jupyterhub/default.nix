{ config, lib, pkgs, ... }:
let
  cfg = config.services.jupyterhub;

  # https://artifacthub.io/packages/helm/bitnami/jupyterhub
  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../charts/jupyterhub-8.1.5.tgz;
    chartName = "jupyterhub";
  };

  defaultNamespace = "jupyterhub";
  domain = "jupyterhub.localhost";
  tls-secret-name = "jupyterhub-tls";

  defaultValues = {
    # ingress.main = {
    #   enabled = true;
    #   hosts = [{
    #     host = domain;
    #     paths = [{ path = "/"; }];
    #   }];
    #   tls = [{
    #     secretName = tls-secret-name;
    #     hosts = [ domain ];
    #   }];
    # };
    # persistence.data.enabled = false;
    # postgresql = {
    #   enabled = true;
    #   primary.persistence.enabled = false;
    # };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.jupyterhub = {
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
    applications.jupyterhub = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.jupyterhub = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
