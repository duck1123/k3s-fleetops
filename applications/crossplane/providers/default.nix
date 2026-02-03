{ lib, ... }:
let
  # providersDir = ./applications/crossplane/providers;
  providersDir = ./.;

  # Get all directories inside `providers/`
  providerDirs = builtins.filter (name:
    (builtins.getAttr name (builtins.readDir providersDir)) == "directory")
    (builtins.attrNames (builtins.readDir providersDir));

  # Import each provider's `default.nix`
  providerModules =
    map (dir: import (providersDir + "/${dir}/default.nix")) providerDirs;
in { imports = providerModules; }
