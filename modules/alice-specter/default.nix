{ charts, config, lib, ... }:
let
  cfg = config.services.alice-specter;

  chartConfig = {
    repo = "https://chart.kronkltd.net/";
    chart = "specter-desktop";
    version = "0.1.0";
    chartHash = "sha256-lzGWuSAzOR/n5iBhg25einXA255SwTm0BRB88lUdEoE=";
  };

  defaultNamespace = "alice-specter";
  domain = "specter-alice.dinsro.com";

  defaultValues = {
    image.tag = "v1.10.3";
    ingress = {
      enabled = true;
      hosts = [{
        host = domain;
        paths = [{ path = "/"; }];
      }];
      tls = [{
        secretName = "alice-specter-prod-tls";
        hosts = [ domain ];
      }];
    };
    persistence.storageClassName = "local-path";
    # TODO: generate json
    nodeConfig = (builtins.toJSON {
      protocol = "http";
      external_node = true;
      # TODO: generate a better password
      password = "rpcpassword";
      name = "alice";
      autodetect = false;
      port = 18443;
      host = "alice-bitcoin";
      alias = "bar";
      fullpath = "/data/.specter/nodes/alice.json";
      datadir = "";
      user = "rpcuser";
    });
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.alice-specter = {
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
    applications.alice-specter = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.alice-specter = { inherit chart values; };
    };
  };
}
