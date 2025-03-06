{
  description = "My ArgoCD configuration with nixidy.";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { flake-utils, nixhelm, nixidy, nixpkgs, self, ... }@inputs:
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        helmChart = import ./helmChart.nix;
      in {
        lib = { inherit helmChart; };

        nixidyEnvs = nixidy.lib.mkEnvs {
          inherit pkgs;
          charts = nixhelm.chartsDerivations.${system};
          envs.dev.modules = [ ./env/dev.nix ];
          libOverlay = final: prev: { inherit helmChart; };
          modules = [ ./modules ];
        };

        packages = {
          generators = {
            cilium = nixidy.packages.${system}.generators.fromCRD {
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
            sealedSecrets = nixidy.packages.${system}.generators.fromCRD {
              name = "sealed-secrets";
              src = pkgs.fetchFromGitHub {
                owner = "bitnami-labs";
                repo = "sealed-secrets";
                rev = "v0.28.0";
                hash = "sha256-YyiYryNLSY8XnrA+3AWeQR2p55YNHFfp/sWCevATdZ0=";
              };
              crds =
                [ "helm/sealed-secrets/crds/bitnami.com_sealedsecrets.yaml" ];
            };
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
              cat ${
                self.packages.${system}.generators.cilium
              } > target/modules/cilium/generated.nix

              echo "generate sealed-secrets"
              mkdir -p modules/sealed-secrets
              cat ${
                self.packages.${system}.generators.sealedSecrets
              } > modules/sealed-secrets/generated.nix
            '').outPath;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixidy.packages.${system}.default
            argo
            argocd
            babashka
            clojure
            docker
            gum
            jet
            keepassxc
            kubectl
            kubernetes-helm
            kubeseal
            openssl
          ];
        };
      }));
}
