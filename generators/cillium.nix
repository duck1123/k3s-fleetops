{
  nixidy,
  pkgs,
  system,
  ...
}:
{
  packages.generators.cilium = nixidy.packages.${system}.generators.fromCRD {
    name = "cilium";
    src = pkgs.fetchFromGitHub {
      owner = "cilium";
      repo = "cilium";
      rev = "v1.15.6";
      hash = "sha256-oC6pjtiS8HvqzzRQsE+2bm6JP7Y3cbupXxCKSvP6/kU=";
    };
    crds = [
      "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumnetworkpolicies.yaml"
      "pkg/k8s/apis/cilium.io/client/crds/v2/ciliumclusterwidenetworkpolicies.yaml"
    ];
  };
}
