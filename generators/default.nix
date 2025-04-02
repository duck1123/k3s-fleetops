{ inputs, system, ... }@sharedConfig:
let
  inherit (inputs) nixpkgs self;
  pkgs = import nixpkgs { inherit system; };
  gFiles = builtins.attrNames (builtins.readDir ./.);
  generatorFiles = builtins.filter
    (file: builtins.match ".*\\.nix" file != null && file != "default.nix")
    gFiles;
  generators = builtins.listToAttrs (map (file: {
    name = builtins.replaceStrings [ ".nix" ] [ "" ] file;
    value = import (./. + "/${file}") sharedConfig;
  }) generatorFiles);
in {
  # inherit generators;

  packages.generators = generators;

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
      cat ${generators.sealed-secrets} > modules/sealed-secrets/generated.nix

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
}
