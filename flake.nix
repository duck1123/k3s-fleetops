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
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        config,
        self,
        withSystem,
        ...
      }:
      {
        imports = [
          make-shell.flakeModules.default
          (inputs.import-tree ./modules)
        ];
        systems = [ "x86_64-linux" ];

        flake.nixidyEnvs = builtins.listToAttrs (
          map (system: {
            name = system;
            value = withSystem system (
              { pkgs, ... }:
              nixidy.lib.mkEnvs {
                inherit pkgs;
                charts = nixhelm.chartsDerivations.${system};
                envs.dev.modules = [ ./env/dev.nix ];
                extraSpecialArgs = { inherit self; };
                modules = [
                  ./applications
                  self.modules.generic.ageRecipients
                ];
              }
            );
          }) config.systems
        );
      }
    );
}
