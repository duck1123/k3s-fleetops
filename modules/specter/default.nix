{ charts, config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "specter";

  chart = lib.helm.downloadHelmChart {
    repo = "https://chart.kronkltd.net/";
    chart = "specter-desktop";
    version = "0.1.0";
    chartHash = "sha256-lzGWuSAzOR/n5iBhg25einXA255SwTm0BRB88lUdEoE=";
  };

  uses-ingress = true;

  extraOptions = {
    imageVersion = mkOption {
      description = mdDoc "The version of bitcoind to deploy";
      type = types.str;
      default = "v2.1.1";
    };
    user-env = mkOption {
      description = mdDoc "The name of the user";
      type = types.str;
      default = "satoshi";
    };
  };

  defaultValues = cfg:
    with cfg; {
      image.tag = imageVersion;

      ingress = with ingress; {
        enabled = true;
        hosts = [{
          host = domain;
          paths = [{ path = "/"; }];
        }];
        tls = [{
          secretName = "specter-prod-tls";
          hosts = [ domain ];
        }];
      };

      persistence.storageClassName = "local-path";

      nodeConfig = builtins.toJSON rec {
        alias = "default";
        autodetect = false;
        datadir = "";
        external_node = true;
        fullpath = "/data/.specter/nodes/${alias}.json";
        host = "${alias}-bitcoin";
        name = alias;
        protocol = "http";
        # TODO: generate a better password
        password = "rpcpassword";
        port = 18443;
        user = "rpcuser";
      };
    };
}
