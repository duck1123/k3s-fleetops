{ config, lib, ... }:
with lib;
let
  appSecrets =
    appName: neededSecrets:
    listToAttrs (
      map (key: {
        name = key;
        value = "${appName}/${key}";
      }) neededSecrets
    );
in
{
  config = {
    services = mapAttrs (appName: appCfg: {
      inherit (appCfg) enable neededSecrets;
      secrets = mkIf appCfg.enable (appSecrets appName appCfg.neededSecrets);
    }) config.services;

    # Optional: Validate that secrets exist
    assertions = map (app: {
      assertion = all (key: app.secrets ? key) app.neededSecrets;
      message = "Service ${appName} is missing required secrets!";
    }) (attrValues config.services);
  };
}
