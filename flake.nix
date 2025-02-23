{
  description = "My ArgoCD configuration with nixidy.";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  };

  outputs = { flake-utils, nixidy, nixpkgs, self, }:
    (flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        nixidyEnvs = nixidy.lib.mkEnvs {
          inherit pkgs;
          envs.dev.modules = [ ./env/dev.nix ];
        };


        packages = {
          generators.cilium = nixidy.packages.${system}.generators.fromCRD {
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
          nixidy = nixidy.packages.${system}.default;
        };

        apps = {
          generate = {
            type = "app";
            program = (pkgs.writeShellScript "generate-modules" ''
              set -eo pipefail

                 echo "generate cilium"
                 mkdir -p target/modules/cilium
                 cat ${self.packages.${system}.generators.cilium} > target/modules/cilium/generated.nix
            '').outPath;
          };
        };

        devShells.default =
          pkgs.mkShell { buildInputs = [ nixidy.packages.${system}.default ]; };
      }));
}
