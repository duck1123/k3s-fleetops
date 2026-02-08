{ ... }:
{
  flake.lib.encryptString =
    {
      ageRecipients,
      pkgs,
      secretName,
      value,
    }:
    let
      json-file = builtins.toFile "input.json" value;
    in
    builtins.readFile (
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
        ''
    );
}
