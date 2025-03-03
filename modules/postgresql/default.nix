{ charts, config, lib, pkgs, ... }:
let
  cfg = config.services.postgresql;

  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../charts/postgresql-16.2.3.tgz;
    chartName = "forgejo";
  };

  defaultNamespace = "postgresql";
  domain = "postgresql.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    global.postgresql.auth = {
      existingSecret = "postgresql-password";
      secretKeys = {
        adminPasswordKey = "adminPassword";
        userPasswordKey = "userPassword";
        replicationPasswordKey = "replicationPassword";
      };
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.postgresql = {
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
    applications.postgresql = {
      inherit namespace;
      createNamespace = true;
      helm.releases.postgresql = { inherit chart values; };
      syncPolicy.finalSyncOpts = ["CreateNamespace=true"];
    };
  };
}
