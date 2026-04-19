{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.flakeModules
  ];
  # Export a flakeModule that dotfiles (or any other consumer) can import to get:
  #   - flake.lib option + utility functions (loadSecrets, fromYAML, toYAML, mkArgoApp, waitForGluetun)
  #   - flake.nixidyApps option + all application modules
  #   - flake.modules.generic.ageRecipients module
  flake.flakeModules.default = {
    imports = [
      ./flake-parts.nix
      ../lib/fromYAML.nix
      ../lib/toYAML.nix
      ../lib/loadSecrets.nix
      ../lib/mkArgoApp.nix
      ../lib/waitForGluetun.nix
      ../applications.nix
      ../sops.nix
    ];
  };
}
