{ charts, config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "alice-specter";

  chart = lib.helm.downloadHelmChart {
    repo = "https://chart.kronkltd.net/";
    chart = "specter-desktop";
    version = "0.1.0";
    chartHash = "sha256-lzGWuSAzOR/n5iBhg25einXA255SwTm0BRB88lUdEoE=";
  };

  uses-ingress = true;

  extraOptions = {
    imageVersion = mkOption {
      description = mdDoc "The version of bitcoind do deploy";
      type = types.str;
      default = "v1.10.3";
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
          secretName = "${user-env}-specter-prod-tls";
          hosts = [ domain ];
        }];
      };
      persistence.storageClassName = "local-path";

      nodeConfig = (builtins.toJSON {
        alias = "bar";
        autodetect = false;
        datadir = "";
        external_node = true;
        fullpath = "/data/.specter/nodes/${user-env}.json";
        host = "${user-env}-bitcoin";
        name = user-env;
        protocol = "http";
        # TODO: generate a better password
        password = "rpcpassword";
        port = 18443;
        user = "rpcuser";
      });
    };
}
