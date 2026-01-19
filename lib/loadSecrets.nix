{ fromYAML, pkgs }:
let
  decryptedPath = builtins.getEnv "DECRYPTED_SECRET_FILE";
  hasDecrypted = builtins.pathExists decryptedPath;
  secrets =
    if hasDecrypted then
      fromYAML {
        inherit pkgs;
        value = builtins.readFile decryptedPath;
      }
    else
      throw "Missing decrypted secret: ${decryptedPath}";
in
secrets
