{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      generators = import ../generators { inherit inputs system pkgs; };
    in
    {
      imports = [
        generators
      ];

      apps = { inherit (generators.apps) generate; };
    };
}
