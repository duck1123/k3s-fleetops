{ pkgs, value }:
let
  yaml-file = builtins.toFile "input.yaml" value;
  json-drv = pkgs.runCommand "convert-from-yaml" {
    nativeBuildInputs = [ pkgs.yq ];
  } ''
    cat ${yaml-file} | yq . > $out
  '';
  json-str = builtins.readFile json-drv;
  parsed-object = builtins.fromJSON json-str;
in parsed-object
