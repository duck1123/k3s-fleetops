{
  charts,
  config,
  lib,
  self,
  ...
}:
self.lib.mkArgoApp { inherit config lib; } {
  name = "cert-manager";
  # https://artifacthub.io/packages/helm/cert-manager/cert-manager
  chart = charts.jetstack.cert-manager;
  defaultValues = cfg: { crds.enabled = true; };
}
