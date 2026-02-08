{ ... }:
{
  flake.lib.loadSecrets =
    { fromYAML, pkgs }:
    let
      decryptedPath = builtins.getEnv "DECRYPTED_SECRET_FILE";
    in
    (
      if (builtins.pathExists decryptedPath) then
        fromYAML {
          inherit pkgs;
          value = builtins.readFile decryptedPath;
        }
      else
        throw "Missing decrypted secret: ${decryptedPath}"
    );
}
