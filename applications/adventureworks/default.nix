{ config, lib, self, ... }:
self.lib.mkArgoApp { inherit config lib; } {
  name = "adventureworks";

  chart = lib.helm.downloadHelmChart {
    repo = "https://chart.kronkltd.net/";
    version = "0.1.0";
    chartHash = "sha256-GMqmF862sBNjYrdbbS1nl9Fw0jbfwo5vj3dEpxZXHu0=";
    chart = "adventureworks";
  };

  defaultValues = cfg: { };
}
