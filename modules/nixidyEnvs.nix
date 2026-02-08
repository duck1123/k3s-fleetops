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
    {
      nixidyEnvs = inputs.nixidy.lib.mkEnvs {
        inherit pkgs;
        charts = inputs.nixhelm.chartsDerivations.${system};
        envs.dev.modules = [ ../env/dev.nix ];
        extraSpecialArgs = { inherit self; };
        modules = [
          ../applications
          self.modules.generic.ageRecipients
        ];
      };
    };

  transposition.nixidyEnvs = {
    adHoc = true;
  };
}
