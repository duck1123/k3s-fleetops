{ charts, config, lib, ... }:
let
  cfg = config.services.alice-lnd;

  chartConfig = {
    repo = "https://chart.kronkltd.net/";
    chart = "lnd-desktop";
    version = "0.1.0";
    chartHash = "sha256-lzGWuSAzOR/n5iBhg25einXA255SwTm0BRB88lUdEoE=";
  };

  userEnv = "alice";
  defaultNamespace = "${userEnv}-lnd";
  domain = "lnd-${userEnv}.dinsro.com";
  imageVersion = "v1.10.3";

  defaultValues = {
    configurationFile = ''
lnd.conf"
  "[Bitcoin]
bitcoin.active=1
bitcoin.mainnet=0
bitcoin.testnet=0
bitcoin.regtest=1
bitcoin.node=bitcoind

[Bitcoind]
bitcoind.rpchost=bitcoin.alice:18443
bitcoind.rpcuser=rpcuser
bitcoind.rpcpass=rpcpassword
bitcoind.zmqpubrawblock=tcp://bitcoin.alice:28332
bitcoind.zmqpubrawtx=tcp://bitcoin.alice:28333

[Application Options]
debuglevel=info
restlisten=0.0.0.0:8080
rpclisten=0.0.0.0:10009
tlsextradomain=lnd.alice.svc.cluster.local
tlsextraip=0.0.0.0
alias=Node alice
'';
    loop.enable = false;
    pool.enable = false;
    persistence.enable = false;
    autoUnlock = false;
    autoUnlockPassword = "unlockpassword";
    network = "regtest";
    ingress.host = "lnd.alice.demo.dinsro.com";


  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.alice-lnd = {
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
    applications.alice-lnd = let chart = helm.downloadHelmChart chartConfig;
    in {
      inherit namespace;
      createNamespace = true;
      helm.releases.alice-lnd = { inherit chart values; };
    };
  };
}
