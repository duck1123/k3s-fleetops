{ charts, config, lib, ... }:
let
  cfg = config.services.metabase;

  chartConfig = {
    repo = "https://pmint93.github.io/helm-charts";
    chart = "metabase";
    version = "2.17.1";
    chartHash = "sha256-Q7oKIMK93F26/pf2TNw+GWcHNwpNrCc9oNeS6NKPAbg=";
  };

  defaultNamespace = "metabase";
  domain = "metabase.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    replicaCount = 1;
    monitoring.enabled = true;
    ingress = {
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      enabled = true;
      hosts = [ "metabase.dev.kronkltd.net" ];
      tls = [{
        secretName = "metabase-tls";
        hosts = [ "metabase.dev.kronkltd.net" ];
      }];
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.metabase = {
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
    applications.metabase = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.metabase = { inherit chart values; };
    };
  };
}
