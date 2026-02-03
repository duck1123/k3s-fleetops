{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "crossplane";

  # https://artifacthub.io/packages/helm/crossplane/crossplane
  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.crossplane.io/master/";
    chart = "crossplane";
    version = "1.20.0-rc.0.24.g01782c157";
    chartHash = "sha256-mzXUVxHhDgJ9bPH+4Msr8lzlQ74PkK/tw+n9n0xYvYA=";
  };

  defaultValues = cfg: { image.pullPolicy = "Always"; };

  extraConfig = cfg: { nixidy.resourceImports = [ ./generated.nix ]; };
} // {
  imports = [ ./providers ];
}
