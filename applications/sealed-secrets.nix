{ ... }:
{
  flake.nixidyApps.sealed-secrets =
    {
      config,
      crdImports,
      lib,
      ...
    }:
    let
      cfg = config.services.sealed-secrets;

      # https://artifacthub.io/packages/helm/bitnami/sealed-secrets
      chart = lib.helm.downloadHelmChart {
        repo = "oci://registry-1.docker.io/bitnamicharts";
        chart = "sealed-secrets";
        version = "2.5.19";
        chartHash = "sha256-KSF9ZHnMUi1NPkuybBhyj/RMcx0J9zh2SU5QNLPd9B4=";
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
        nixidy.applicationImports = [ (toString crdImports."sealed-secrets") ];

        applications.sealed-secrets = {
          inherit namespace;
          createNamespace = true;
          finalizer = "foreground";
          helm.releases.sealed-secrets = { inherit chart values; };
          syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
        };
      };
    };
}
