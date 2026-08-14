{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      site = pkgs.buildNpmPackage {
        pname = "duck1123-site";
        version = "0.1.0";
        src = ../../applications/duck1123-site;
        # nix build .#duck1123-site  →  first failure shows the correct hash
        npmDepsHash = "sha256-zkrWShQU8Jz6vh+DRL0ILyVP83yl2TUAr/7eZTpcjig=";

        installPhase = ''
          mkdir -p $out
          cp -r dist/. $out/
        '';
      };
    in
    {
      # nix build .#duck1123-site
      packages.duck1123-site = site;
    };
}
