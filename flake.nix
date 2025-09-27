{
  description = "My ArgoCD configuration with nixidy.";

  inputs = {
    clj-nix = {
      inputs = {
        nix-fetcher-data.follows = "nix-fetcher-data";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:jlesquembre/clj-nix";
    };

    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
      url = "github:hercules-ci/flake-parts";
    };

    flake-utils = {
      inputs.systems.follows = "systems";
      url = "github:numtide/flake-utils";
    };

    make-shell.url = "github:nicknovitski/make-shell";

    nix-fetcher-data = {
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:jlesquembre/nix-fetcher-data";
    };

    nix-kube-generators.url = "github:farcaller/nix-kube-generators";

    nixhelm = {
      inputs = {
        flake-utils.follows = "flake-utils";
        nix-kube-generators.follows = "nix-kube-generators";
        nixpkgs.follows = "nixpkgs";
        poetry2nix.follows = "poetry2nix";
      };
      url = "github:farcaller/nixhelm";
    };

    nixidy = {
      inputs = {
        flake-utils.follows = "flake-utils";
        nix-kube-generators.follows = "nix-kube-generators";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:duck1123/nixidy?ref=feature/chmod";
    };

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";

    poetry2nix = {
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
      url = "github:nix-community/poetry2nix";
    };

    sops-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Mic92/sops-nix";
    };

    systems.url = "github:nix-systems/default";
  };

  outputs = { flake-parts, make-shell, nixhelm, nixidy, nixpkgs, ... }@inputs:
    let
      # FIXME: naughty config
      ageRecipients =
        "age1n372e8dgautnjhecllf7uvvldw9g6vyx3kggj0kyduz5jr2upvysue242c";
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = (import ./lib) // {
        inherit ageRecipients;
        sopsConfig = ./.sops.yaml;
      };
      secrets = lib.loadSecrets {
        inherit (lib) fromYAML;
        inherit pkgs;
      };
      dev = import ./env/dev.nix { inherit lib nixidy secrets; };
      charts = nixhelm.chartsDerivations.${system};
      defaultEnv = nixidy.lib.mkEnvs {
        inherit charts pkgs;
        extraSpecialArgs = { inherit ageRecipients; };
        envs.dev.modules = [ dev ];
        libOverlay = final: prev: lib;
        modules = [ ./modules ];
      };
    in flake-parts.lib.mkFlake { inherit inputs; } (_: {
      imports = [ make-shell.flakeModules.default ];
      systems = [ system ];
      perSystem = { pkgs, system, ... }:
        let generators = import ./generators { inherit inputs system pkgs; };
        in {
          imports = [ generators ];
          apps = { inherit (generators.apps) generate; };

          make-shells.default = { pkgs, ... }: {
            packages = with pkgs; [
              nixidy.packages.${system}.default
              age
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
              sops
              ssh-to-age
              ssh-to-pgp
              yq
            ];
          };

          packages.nixidy = nixidy.packages.${system}.default;
        };
    }) // {
      inherit lib;
      # TODO: Make a flake-parts module for this
      nixidyEnvs.${system} = defaultEnv;
    };
}
