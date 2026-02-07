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

    import-tree.url = "github:vic/import-tree";

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
      };
      url = "github:farcaller/nixhelm";
    };

    nixidy = {
      inputs = {
        flake-utils.follows = "flake-utils";
        nix-kube-generators.follows = "nix-kube-generators";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:arnarg/nixidy";
    };

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";

    sops-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:Mic92/sops-nix";
    };

    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      flake-parts,
      make-shell,
      nixhelm,
      nixidy,
      self,
      ...
    }@inputs:
    let
      ageRecipients = (self.modules.common.ageRecipients { }).ageRecipients;
      lib = (import ./lib) // {
        inherit ageRecipients;
        sopsConfig = ./.sops.yaml;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, withSystem, ... }:
      {
        imports = [
          make-shell.flakeModules.default
          (inputs.import-tree ./modules)
        ];
        systems = [ "x86_64-linux" ];
        perSystem =
          { pkgs, system, ... }:
          let
            generators = import ./generators { inherit inputs system pkgs; };
          in
          {
            imports = [ generators ];
            apps = { inherit (generators.apps) generate; };
            packages.nixidy = nixidy.packages.${system}.default;
          };
        flake = {
          inherit lib;
          # Compute nixidyEnvs per system using withSystem
          nixidyEnvs = builtins.listToAttrs (
            map (system: {
              name = system;
              value = withSystem system (
                { pkgs, ... }:
                let
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
                    modules = [ ./applications ];
                  };
                in
                defaultEnv
              );
            }) config.systems
          );
        };
      }
    );
}
