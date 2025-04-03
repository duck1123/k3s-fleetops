{ pkgs, sopsConfig }:
{ secretName, value }:
let
  encrypted-drv =
    pkgs.runCommand secretName { nativeBuildInputs = [ pkgs.jq pkgs.sops ]; } ''
      echo ${value} | sops --encrypt --config ${sopsConfig} /dev/stdin | jq -r .data > $out
    '';
in builtins.readFile encrypted-drv
