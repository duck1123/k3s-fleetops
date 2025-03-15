{
  description = "My ArgoCD configuration with nixidy.";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixidy = {
      url = "github:duck1123/nixidy?ref=feature/chmod";
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
            cert-manager = nixidy.packages.${system}.generators.fromCRD {
              name = "cert-manager";
              src = pkgs.fetchFromGitHub {
                owner = "cert-manager";
                repo = "cert-manager";
                rev = "v1.17.1";
                hash = "sha256-cp4y4NULf2e9lwwO4OiAbUNfXkE20ptnSTZjOMmFKgM=";
              };
              crds = [
                "deploy/crds/crd-certificaterequests.yaml"
                "deploy/crds/crd-certificates.yaml"
                "deploy/crds/crd-challenges.yaml"
                "deploy/crds/crd-clusterissuers.yaml"
                "deploy/crds/crd-issuers.yaml"
                "deploy/crds/crd-orders.yaml"
              ];
            };
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
            crossplane = nixidy.packages.${system}.generators.fromCRD {
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
            sops = nixidy.packages.${system}.generators.fromCRD {
              name = "sops";
              src =
                nixhelm.chartsDerivations.${system}.isindir.sops-secrets-operator;
              crds = [ "crds/isindir.github.com_sopssecrets.yaml" ];
            };
            tailscale = nixidy.packages.${system}.generators.fromCRD {
              name = "tailscale";
              src = pkgs.fetchFromGitHub {
                owner = "tailscale";
                repo = "tailscale";
                rev = "v1.72.1";
                hash = "sha256-b1o3UHotVs5/+cpMx9q8bvt6BSM2QamLDUNyBNfb58A=";
              };
              crds = [
                "cmd/k8s-operator/deploy/crds/tailscale.com_proxyclasses.yaml"
              ];
            };
            traefik = nixidy.packages.${system}.generators.fromCRD {
              name = "traefik";
              src = nixhelm.chartsDerivations.${system}.traefik.traefik;
              crds = [
                "crds/traefik.io_ingressroutes.yaml"
                "crds/traefik.io_ingressroutetcps.yaml"
                "crds/traefik.io_ingressrouteudps.yaml"
                "crds/traefik.io_traefikservices.yaml"
              ];
            };
          };
          nixidy = nixidy.packages.${system}.default;
        };

        apps.generate = let generators = self.packages.${system}.generators;
        in {
          type = "app";
          program = (pkgs.writeShellScript "generate-modules" ''
            set -eo pipefail

            echo "generate cert-manager"
            mkdir -p modules/cert-manager
            cat ${generators.cert-manager} > modules/cert-manager/generated.nix

            echo "generate cilium"
            mkdir -p modules/cilium
            cat ${generators.cilium} > modules/cilium/generated.nix

            echo "generate crossplane"
            mkdir -p modules/crossplane
            cat ${generators.crossplane} > modules/crossplane/generated.nix

            echo "generate sealed-secrets"
            mkdir -p modules/sealed-secrets
            cat ${generators.sealedSecrets} > modules/sealed-secrets/generated.nix

            echo "generate sops"
            mkdir -p modules/sops
            cat ${generators.sops} > modules/sops/generated.nix

            echo "generate tailscale"
            mkdir -p modules/tailscale
            cat ${generators.tailscale} > modules/tailscale/generated.nix

            echo "generate traefik"
            mkdir -p modules/traefik
            cat ${generators.traefik} > modules/traefik/generated.nix
          '').outPath;
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
