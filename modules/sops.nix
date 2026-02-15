{ lib, ... }:
{
  flake.modules.generic.ageRecipients =
    { ... }:
    {
      options.ageRecipients = lib.mkOption {
        type = lib.types.str;
        default = { };
        description = "The age key that should be used to encrypt sops secrets";
      };
    };

  # When set (e.g. by CI: NIXIFY_PRE_ENCRYPTED_SECRETS_DIR=./ci-secrets), secrets are loaded
  # from JSON files in this dir instead of creating them at eval time (avoids plaintext in store).
  flake.modules.generic.preEncryptedSecretsDir =
    { ... }:
    {
      options.preEncryptedSecretsDir = lib.mkOption {
        type = lib.types.str;
        default = builtins.getEnv "NIXIFY_PRE_ENCRYPTED_SECRETS_DIR";
        description = "If non-empty, load sops secret JSONs from this dir instead of createSecret (set by CI)";
      };
    };
}
