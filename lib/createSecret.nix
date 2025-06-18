# Takes unencrypted values and returns the config for a sopssecret containing encrypted values
{ ageRecipients, lib, namespace ? "default", pkgs, secretName ? "some-secret"
, values ? { }, ... }:
let
  encrypted-object = builtins.fromJSON (lib.encryptString {
    inherit ageRecipients secretName;
    value = (lib.toYAML {
      inherit pkgs;
      value = {
        apiVersion = "isindir.github.com/v1alpha3";
        kind = "SopsSecret";
        metadata = {
          inherit namespace;
          name = secretName;
        };
        spec.secretTemplates = [{
          name = secretName;
          stringData = values;
        }];
      };
    });
  });
in { inherit (encrypted-object) sops spec; }
