{ charts, config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "alice-bitcoin";

  # https://artifacthub.io/packages/helm/kronkltd/bitcoind
  chart = lib.helm.downloadHelmChart {
    repo = "https://chart.kronkltd.net/";
    chart = "bitcoind";
    version = "0.2.3";
    chartHash = "sha256-iSi8hY8TufXdqdDujPzdbLSOKFfIehVnpshIhUG4NBE=";
  };

  defaultValues = cfg: {
    fullNameOverride = "alice-bitcoin";
    image = {
      repository = "ruimarinho/bitcoin-core";
      tag = "22";
    };
    configurationFile = {
      "bitcoin.conf" = ''
        regtest=1
        server=1
        txindex=1
        printtoconsole=1
        blockfilterindex=1
        txindex=1
        rpcauth=rpcuser:3de4eb23a68a288cfbc857d3cf52b5c4$0b28c21a8d32d047b4da6b4b5f290951319bad3cb0985ef863c8fa4614f3c109
        rpcallowip=0.0.0.0/0
        whitelist=0.0.0.0/0
        zmqpubrawblock=tcp://0.0.0.0:28332
        zmqpubrawtx=tcp://0.0.0.0:28333
        zmqpubhashblock=tcp://0.0.0.0:28334
        [regtest]
        rpcbind=0.0.0.0
      '';
    };
  };
}
