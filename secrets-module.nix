{ lib, ... }:
with lib;
{
  options = {
    secrets = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            keepassPath = mkOption {
              type = types.listOf types.str;
              description = "Path inside Keepass database to the secret.";
            };
            description = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Optional description of what this secret is for.";
            };
            env = mkOption {
              type = types.nullOr (
                types.enum [
                  "production"
                  "staging"
                  "development"
                ]
              );
              default = null;
              description = "Environment tag, if needed.";
            };
          };
        }
      );
      description = "Secrets definition mapping.";
    };
  };
}
