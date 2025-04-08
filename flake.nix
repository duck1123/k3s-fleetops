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

    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { flake-utils, nixhelm, nixidy, nixpkgs, ... }@inputs:
    (flake-utils.lib.eachDefaultSystem (system:
      let
        # naughty config
        ageRecipients =
          "age1n372e8dgautnjhecllf7uvvldw9g6vyx3kggj0kyduz5jr2upvysue242c";

        pkgs = import nixpkgs { inherit system; };
        encryptString =
          import ./encryptString.nix { inherit ageRecipients pkgs; };
        helmChart = import ./helmChart.nix;
        sharedConfig = { inherit inputs system pkgs; };
        toYAML = import ./toYAML.nix;
        generators = import ./generators sharedConfig;
        lib = {
          inherit ageRecipients encryptString helmChart toYAML;
          sopsConfig = ./.sops.yaml;
        };
      in {
        inherit lib;
        imports = [ generators ];

        apps = { inherit (generators.apps) generate; };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
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

        nixidyEnvs = nixidy.lib.mkEnvs {
          inherit pkgs;
          charts = nixhelm.chartsDerivations.${system};
          envs.dev.modules = [ ./env/dev.nix ];
          libOverlay = final: prev: lib;
          modules = [ ./modules ];
        };

        packages.nixidy = nixidy.packages.${system}.default;
      }));
}
