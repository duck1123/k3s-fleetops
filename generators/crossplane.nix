{
  inputs,
  pkgs,
  system,
  ...
}:
let
  inherit (inputs.nixidy.packages.${system}.generators) fromCRD;
in
fromCRD {
  name = "crossplane";
  src = pkgs.fetchFromGitHub {
    owner = "crossplane";
    repo = "crossplane";
    rev = "v1.19.0";
    hash = "sha256-HSTECDo6jPa9yXziWxPnOvtCC0Xai6yG2orAn1AfAGw=";
  };
  crds = [
    "cluster/crds/apiextensions.crossplane.io_compositeresourcedefinitions.yaml"
    "cluster/crds/apiextensions.crossplane.io_compositionrevisions.yaml"
    "cluster/crds/apiextensions.crossplane.io_compositions.yaml"
    "cluster/crds/apiextensions.crossplane.io_environmentconfigs.yaml"
    "cluster/crds/apiextensions.crossplane.io_usages.yaml"
    "cluster/crds/pkg.crossplane.io_configurationrevisions.yaml"
    "cluster/crds/pkg.crossplane.io_configurations.yaml"
    "cluster/crds/pkg.crossplane.io_controllerconfigs.yaml"
    "cluster/crds/pkg.crossplane.io_deploymentruntimeconfigs.yaml"
    "cluster/crds/pkg.crossplane.io_functionrevisions.yaml"
    "cluster/crds/pkg.crossplane.io_functions.yaml"
    "cluster/crds/pkg.crossplane.io_imageconfigs.yaml"
    "cluster/crds/pkg.crossplane.io_locks.yaml"
    "cluster/crds/pkg.crossplane.io_providerrevisions.yaml"
    "cluster/crds/pkg.crossplane.io_providers.yaml"
    "cluster/crds/secrets.crossplane.io_storeconfigs.yaml"
  ];
}
