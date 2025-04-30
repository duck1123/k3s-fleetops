{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "pihole";

  # https://artifacthub.io/packages/helm/savepointsam/pihole
  chart = lib.helm.downloadHelmChart {
    repo = "https://savepointsam.github.io/charts";
    chart = "pihole";
    version = "0.2.0";
    chartHash = "sha256-jwqcjoQXi41Y24t4uGqnw6JVhB2bBbiv5MasRTbq3hA=";
  };

  uses-ingress = true;
}
