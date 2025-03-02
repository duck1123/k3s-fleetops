{ charts, config, lib, ... }:
let
  cfg = config.services.redis;

  chartConfig = {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "redis";
    version = "20.10.0";
    chartHash = "sha256-gK0+tInWSSrXUSnKbcYQzZqSjVptbZa7np1ZsqhaNDw=";
  };

  defaultNamespace = "redis";
  domain = "redis.dev.kronkltd.net";

  defaultValues = {
    auth = {
      existingSecret = "redis-password";
      existingSecretPasswordKey = "password";
    };

    replicas.replicaCount = 1;
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.redis = {
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
    applications.redis = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.redis = { inherit chart values; };
    };
  };
}
