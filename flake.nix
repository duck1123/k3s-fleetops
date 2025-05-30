{
  description = "My ArgoCD configuration with nixidy.";

  inputs = {
    clj-nix = {
      url = "github:jlesquembre/clj-nix";
      inputs.nix-fetcher-data.follows = "nix-fetcher-data";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat.url = "github:edolstra/flake-compat";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    };

    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };

    kubenix = {
      url = "github:hall/kubenix";
      inputs.flake-compat.follows = "flake-compat";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };

    make-shell = {
      url = "github:nicknovitski/make-shell";
      inputs.flake-compat.follows = "flake-compat";
    };

    mkdocs-flake = {
      url = "github:applicative-systems/mkdocs-flake";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.poetry2nix.follows = "poetry2nix";
    };

    nix-fetcher-data = {
      url = "github:jlesquembre/nix-fetcher-data";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-kube-generators.url = "github:farcaller/nix-kube-generators";

    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nix-kube-generators.follows = "nix-kube-generators";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.poetry2nix.follows = "poetry2nix";
    };

    nixidy = {
      url = "github:duck1123/nixidy?ref=feature/chmod";
      inputs.flake-utils.follows = "flake-utils";
      inputs.kubenix.follows = "kubenix";
      inputs.nix-kube-generators.follows = "nix-kube-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";

    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    systems.url = "github:nix-systems/default";
  };

  outputs = { nixhelm, nixidy, nixpkgs, ... }@inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (_: {
      imports = [
        inputs.mkdocs-flake.flakeModules.default
        inputs.make-shell.flakeModules.default
      ];
      systems = [ "x86_64-linux" ];
      perSystem = { pkgs, system, ... }:
        let generators = import ./generators { inherit inputs system pkgs; };
        in {
          imports = [ generators ];

          apps = { inherit (generators.apps) generate; };
          documentation.mkdocs-root = ./.;

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

          packages = { nixidy = nixidy.packages.${system}.default; };
        };
    }) // (let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # naughty config
      ageRecipients =
        "age1n372e8dgautnjhecllf7uvvldw9g6vyx3kggj0kyduz5jr2upvysue242c";
      encryptString =
        import ./lib/encryptString.nix { inherit ageRecipients pkgs; };
      createSecret = import ./lib/createSecret.nix;
      helmChart = import ./lib/helmChart.nix;
      fromYAML = import ./lib/fromYAML.nix;
      mkArgoApp = import ./lib/mkArgoApp.nix;
      toYAML = import ./lib/toYAML.nix;
      lib = {
        inherit ageRecipients createSecret encryptString fromYAML helmChart
          mkArgoApp toYAML;
        sopsConfig = ./.sops.yaml;
      };
      decryptedPath = builtins.getEnv "DECRYPTED_SECRET_FILE";
      hasDecrypted = builtins.pathExists decryptedPath;
      secrets = if hasDecrypted then
        fromYAML {
          inherit pkgs;
          value = builtins.readFile decryptedPath;
        }
      else
        throw "Missing decrypted secret: ${decryptedPath}";
      dev = import ./env/dev.nix { inherit lib nixidy secrets; };
    in {
      inherit lib;

      nixidyEnvs.${system} = nixidy.lib.mkEnvs {
        inherit pkgs;
        charts = nixhelm.chartsDerivations.${system};
        envs.dev.modules = [ dev ];
        libOverlay = final: prev: lib;
        modules = [ ./modules ];
      };
    });
}
