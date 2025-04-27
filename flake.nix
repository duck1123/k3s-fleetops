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
          import ./lib/encryptString.nix { inherit ageRecipients pkgs; };
        createSecret = import ./lib/createSecret.nix;
        helmChart = import ./lib/helmChart.nix;
        fromYAML = import ./lib/fromYAML.nix;
        mkArgoApp = import ./lib/mkArgoApp.nix;
        toYAML = import ./lib/toYAML.nix;
        generators = import ./generators { inherit inputs system pkgs; };

        # TODO: extract all this
        decryptedPath = builtins.getEnv "DECRYPTED_SECRET_FILE";
        hasDecrypted = builtins.pathExists decryptedPath;
        secrets = if hasDecrypted then
          fromYAML {
            inherit pkgs;
            value = builtins.readFile decryptedPath;
          }
        else
          throw "Missing decrypted secret: ${decryptedPath}";
        lib = {
          inherit ageRecipients createSecret encryptString fromYAML helmChart
            mkArgoApp toYAML;
          sopsConfig = ./.sops.yaml;
        };
        dev = import ./env/dev.nix { inherit lib nixidy secrets; };
        modules = [  ./modules ];
      in {
        inherit lib modules;
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
          inherit modules pkgs;
          charts = nixhelm.chartsDerivations.${system};
          envs.dev.modules = [ dev ];
          libOverlay = final: prev: lib;
        };

        packages = {
          generate-secrets = pkgs.writeShellScriptBin "generate-secrets" ''
            #!/usr/bin/env bash
            set -euo pipefail

            secrets_json=$(nix eval --json --file ./secrets.nix)

            DB_PATH=$1
            OUTPUT_FILE=$2

            tmpfile=$(mktemp)

            # Loop over JSON and fetch passwords
            echo "$secrets_json" | jq -r 'to_entries[] | "\(.key) \(.value.keepassPath | join("/"))"' | while read -r key path; do
              value=$(keepassxc-cli show -s "$DB_PATH" "$path" 2>/dev/null || echo "**MISSING**")
              yaml_key=$(echo "$key" | sed 's/\./:/g') # We'll nest later
              echo "$yaml_key: \"$value\"" >> "$tmpfile"
            done

            # Turn : into nesting
            yq -n --from-file "$tmpfile" > "$OUTPUT_FILE"

            echo "Secrets written to $OUTPUT_FILE"
          '';

          nixidy = nixidy.packages.${system}.default;
        };
      }));
}
