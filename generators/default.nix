{ inputs, system, ... }@sharedConfig:
let
  inherit (inputs) nixpkgs self;
  pkgs = import nixpkgs { inherit system; };
  sharedConfigWithPkgs = sharedConfig // {
    inherit pkgs;
  };
  gFiles = builtins.attrNames (builtins.readDir ./.);
  generatorFiles = builtins.filter (
    file: builtins.match ".*\\.nix" file != null && file != "default.nix"
  ) gFiles;
  generators = builtins.listToAttrs (
    map (file: {
      name = builtins.replaceStrings [ ".nix" ] [ "" ] file;
      value = import (./. + "/${file}") sharedConfigWithPkgs;
    }) generatorFiles
  );
in
{
  apps.generate = {
    type = "app";
    program =
      (pkgs.writeShellScript "generate-modules" ''
        set -eo pipefail

        echo "generate cert-manager"
        mkdir -p applications/cert-manager
        cat ${generators.cert-manager} > applications/cert-manager/generated.nix

        echo "generate cilium"
        mkdir -p applications/cilium
        cat ${generators.cilium} > applications/cilium/generated.nix

        echo "generate crossplane"
        mkdir -p applications/crossplane
        cat ${generators.crossplane} > applications/crossplane/generated.nix

        echo "generate sealed-secrets"
        mkdir -p applications/sealed-secrets
        cat ${generators.sealed-secrets} > applications/sealed-secrets/generated.nix

        echo "generate sops"
        mkdir -p applications/sops
        cat ${generators.sops} > applications/sops/generated.nix

        echo "generate tailscale"
        mkdir -p applications/tailscale
        cat ${generators.tailscale} > applications/tailscale/generated.nix

        echo "generate traefik"
        mkdir -p applications/traefik
        cat ${generators.traefik} > applications/traefik/generated.nix
      '').outPath;
  };

  apps.generate-docs = {
    type = "app";
    program = generators.docs;
  };
}
