{ inputs, self, ... }:
{
  # inputs.nixidy = {
  #   inputs = {
  #     flake-utils.follows = "flake-utils";
  #     nix-kube-generators.follows = "nix-kube-generators";
  #     nixpkgs.follows = "nixpkgs";
  #   };
  #   url = "github:arnarg/nixidy";
  # };

  perSystem =
    { pkgs, system, ... }:
    let
      secretsFile = builtins.getEnv "DECRYPTED_SECRET_FILE";
      secretsAvailable = secretsFile != "" && builtins.pathExists secretsFile;
      crdImports = (import ../generators { inherit inputs system pkgs; }).crdImports;
      devEnv = inputs.nixidy.lib.mkEnvs {
        inherit pkgs;
        charts = inputs.nixhelm.chartsDerivations.${system};
        envs.dev.modules = [ ../env/dev.nix ];
        extraSpecialArgs = { inherit self crdImports; };
        modules = (builtins.attrValues self.nixidyApps) ++ [
          self.modules.generic.ageRecipients
          ./secretManifest.nix
          ./secretSpecs.nix
          ./nodeProfiles.nix
        ];
      };
      # For CI: list of { app, secretName, namespace, keys } (metadata only, not secret values).
      devSecretManifest = devEnv.dev.config.nixidy.secretManifest or [ ];
      # For write-sops-secrets.sh: full specs including plaintext values.
      # Exposed as a plain Nix value (not a derivation) so `nix eval` can output it to stdout
      # without any store path being created for the plaintext.
      devSecretSpecs = {
        ageRecipients = devEnv.dev.config.ageRecipients or "";
        secrets = devEnv.dev.config.nixidy.secretSpecs or [ ];
      };
    in
    if !secretsAvailable then
      { }
    else
      {
        nixidyEnvs = devEnv;
        # Package that outputs the secret manifest JSON (for CI script).
        # Use: nix build .#packages.x86_64-linux.devSecretManifest && cat result
        packages.devSecretManifest = pkgs.runCommand "dev-secret-manifest.json" {
          manifest = builtins.toJSON devSecretManifest;
        } ''echo "$manifest" > $out '';
        # Plain Nix value (not a package) for write-sops-secrets.sh.
        # Use: nix eval --impure --json .#nixidySecretSpecs.x86_64-linux.dev
        nixidySecretSpecs.dev = devSecretSpecs;
      };

  transposition.nixidyEnvs = {
    adHoc = true;
  };

  transposition.nixidySecretSpecs = {
    adHoc = true;
  };
}
