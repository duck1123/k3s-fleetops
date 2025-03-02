{ charts, config, lib, ... }:
let
  cfg = config.services.opentelemetry-collector;

  chartConfig = {
    repo = "https://open-telemetry.github.io/opentelemetry-helm-charts";
    chart = "opentelemetry-collector";
    version = "0.107.0";
    chartHash = "sha256-B1pmsE4zsl8saUnBBzljmJY6Lq6vrVuIeTMStpy3pPc=";
  };

  defaultNamespace = "opentelemetry-collector";
  domain = "opentelemetry-collector.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.opentelemetry-collector = {
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
    applications.opentelemetry-collector = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.opentelemetry-collector = { inherit chart values; };
    };
  };
}
