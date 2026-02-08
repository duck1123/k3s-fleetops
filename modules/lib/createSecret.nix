{ self, ... }:
{
  # Takes unencrypted values and returns the config for a sopssecret containing encrypted values
  flake.lib.createSecret =
    {
      ageRecipients,
      namespace ? "default",
      pkgs,
      secretName ? "some-secret",
      values ? { },
      ...
    }:
    let
      secret-spec = {
        apiVersion = "isindir.github.com/v1alpha3";
        kind = "SopsSecret";
        metadata = {
          inherit namespace;
          name = secretName;
        };
        spec.secretTemplates = [
          {
            name = secretName;
            stringData = values;
          }
        ];
      };
      value = self.lib.toYAML {
        inherit pkgs;
        value = secret-spec;
      };
      encrypted-string = self.lib.encryptString {
        inherit
          ageRecipients
          pkgs
          secretName
          value
          ;
      };
      encrypted-object = builtins.fromJSON encrypted-string;
    in
    {
      inherit (encrypted-object) sops spec;
    };
}
