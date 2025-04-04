{ config, lib, ... }:
let
  app-name = "sops";
  cfg = config.services.${app-name};

  # https://artifacthub.io/packages/helm/sops-secrets-operator/sops-secrets-operator
  chart = lib.helm.downloadHelmChart {
    repo = "https://isindir.github.io/sops-secrets-operator/";
    chart = "sops-secrets-operator";
    version = "0.21.0";
    chartHash = "sha256-SmSp9oo8ue9DuRQSHevJSrGVVB5xmmlook53Y8AfUZY=";
  };

  defaultNamespace = app-name;

  defaultValues = {
    extraEnv = [{
      name = "SOPS_AGE_KEY_FILE";
      value = "/etc/sops-age-key-file/key";
    }];
    secretsAsFiles = [{
      mountPath = "/etc/sops-age-key-file";
      name = "sops-age-key-file";
      secretName = "sops-age-key-file";
    }];
  };

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
