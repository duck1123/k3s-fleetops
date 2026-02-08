{ config, self, ... }:
{
  flake.lib.loadSecrets =
    { pkgs }:
    let
      decryptedPath = builtins.getEnv "DECRYPTED_SECRET_FILE";
    in
    (
      if (builtins.pathExists decryptedPath) then
        self.lib.fromYAML {
          inherit pkgs;
          value = builtins.readFile decryptedPath;
        }
      else
        throw "Missing decrypted secret: ${decryptedPath}"
    );
}
