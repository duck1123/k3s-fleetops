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
      devEnv = inputs.nixidy.lib.mkEnvs {
        inherit pkgs;
        charts = inputs.nixhelm.chartsDerivations.${system};
        envs.dev.modules = [ ../env/dev.nix ];
        extraSpecialArgs = { inherit self; };
        modules = [
          ../applications
          self.modules.generic.ageRecipients
          self.modules.generic.preEncryptedSecretsDir
          ./secretManifest.nix
        ];
      };
      # For CI: list of { app, secretName, namespace, keys } (metadata only, not secret values).
      devSecretManifest = devEnv.config.nixidy.secretManifest or [ ];
    in
    {
      nixidyEnvs = devEnv;
      # Package that outputs the secret manifest JSON (for CI script).
      # Use: nix build .#packages.x86_64-linux.devSecretManifest && cat result
      packages.devSecretManifest = pkgs.runCommand "dev-secret-manifest.json" {
        manifest = builtins.toJSON devSecretManifest;
      } ''echo "$manifest" > $out '';
    };

  transposition.nixidyEnvs = {
    adHoc = true;
  };
}
