{
  charts,
  config,
  lib,
  ...
}:
with lib;
mkArgoApp { inherit config lib; } {
  name = "cert-manager";
  # https://artifacthub.io/packages/helm/cert-manager/cert-manager
  chart = charts.jetstack.cert-manager;
  defaultValues = cfg: { crds.enabled = true; };
}
