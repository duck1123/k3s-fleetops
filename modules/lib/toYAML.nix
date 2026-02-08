{ ... }:
{
  # because I want yaml, not "um, json is valid yaml actually"
  flake.lib.toYAML =
    { pkgs, value }:
    let
      yaml-formatter = pkgs.formats.yaml { };
      json-str = (yaml-formatter.generate "config.yaml" value).drvAttrs.value;
      json-file = builtins.toFile "input.json" json-str;
    in
    builtins.readFile (
      pkgs.runCommand "convert-values-yaml"
        {
          nativeBuildInputs = [ pkgs.yq ];
        }
        ''
          cat ${json-file} | yq -y . > $out
        ''
    );
}
