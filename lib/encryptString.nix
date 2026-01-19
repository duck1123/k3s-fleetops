{
  ageRecipients,
  pkgs,
  secretName,
  value,
}:
let
  json-file = builtins.toFile "input.json" value;
  encrypted-drv =
    pkgs.runCommand secretName
      {
        nativeBuildInputs = with pkgs; [
          jq
          sops
          yq
        ];
      }
      ''
        cat ${json-file} | yq -y . > output.yaml
        sops --encrypt --age ${ageRecipients} --encrypted-regex='^(stringData)$' output.yaml > output.enc.yaml
        cat output.enc.yaml | yq . > $out
      '';
  encrypted-string = builtins.readFile encrypted-drv;
in
encrypted-string
