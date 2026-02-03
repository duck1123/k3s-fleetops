{ charts, config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "alice-lnd";

  chart = lib.helm.downloadHelmChart {
    repo = "https://chart.kronkltd.net/";
    chart = "lnd";
    version = "0.3.9";
    chartHash = "sha256-PgA65z/LuWvCfCdTSu9j+CpSS4eWcLY20oSqaBxFklA=";
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

  defaultValues = cfg: {
    autoUnlock = false;
    autoUnlockPassword = "unlockpassword";
    configurationFile."lnd.conf" = ''
      [Bitcoin]
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
    ingress.host = "lnd.alice.demo.dinsro.com";
    loop.enable = false;
    network = "regtest";
    persistence.enable = false;
    pool.enable = false;
  };
}
