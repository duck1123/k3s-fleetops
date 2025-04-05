# because I want yaml, not "um, json is valid yaml actually"
{ pkgs, value }:
let
  yaml-formatter = pkgs.formats.yaml { };
  json-str = (yaml-formatter.generate "config.yaml" value).drvAttrs.value;
  json-file = builtins.toFile "input.json" json-str;
  yaml-drv = pkgs.runCommand "convert-values-yaml" {
    nativeBuildInputs = [ pkgs.yq ];
  } ''
    cat ${json-file} | yq -y . > $out
  '';
  yaml-str = builtins.readFile yaml-drv;
in yaml-str
