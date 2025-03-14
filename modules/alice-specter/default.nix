{ config, lib, ... }:
let
  cfg = config.services.alice-specter;

  chart = lib.helm.downloadHelmChart {
    repo = "https://chart.kronkltd.net/";
    chart = "specter-desktop";
    version = "0.1.0";
    chartHash = "sha256-lzGWuSAzOR/n5iBhg25einXA255SwTm0BRB88lUdEoE=";
  };

  userEnv = "alice";
  defaultNamespace = "${userEnv}-specter";
  domain = "specter-${userEnv}.dinsro.com";
  imageVersion = "v1.10.3";

  defaultValues = {
    image.tag = imageVersion;
    ingress = {
      enabled = true;
      hosts = [{
        host = domain;
        paths = [{ path = "/"; }];
      }];
      tls = [{
        secretName = "${userEnv}-specter-prod-tls";
        hosts = [ domain ];
      }];
    };
    persistence.storageClassName = "local-path";

    nodeConfig = (builtins.toJSON {
      alias = "bar";
      autodetect = false;
      datadir = "";
      external_node = true;
      fullpath = "/data/.specter/nodes/${userEnv}.json";
      host = "${userEnv}-bitcoin";
      name = userEnv;
      protocol = "http";
      # TODO: generate a better password
      password = "rpcpassword";
      port = 18443;
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
    applications.alice-specter = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.alice-specter = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
