{ config, lib, ... }:
let
  cfg = config.services.sealed-secrets;

  # https://artifacthub.io/packages/helm/bitnami-labs/sealed-secrets
  chart = lib.helm.downloadHelmChart {
    repo = "https://bitnami-labs.github.io/sealed-secrets";
    chart = "sealed-secrets";
    version = "2.16.2";
    chartHash = "sha256-zye4S10OqY5ERoFHRuwAe9IpnmK1T21x5CQqPYp4y8M=";
  };

  defaultNamespace = "sealed-secrets";

  defaultValues = { };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in
with lib;
{
  options.services.sealed-secrets = {
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
    nixidy.resourceImports = [ ./generated.nix ];

    applications.sealed-secrets = {
      inherit namespace;
      createNamespace = true;
      finalizer = "foreground";
      helm.releases.sealed-secrets = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
