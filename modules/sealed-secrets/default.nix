{ lib, config, charts, nixidy, ... }: {
  nixidy.resourceImports = [ ./generated.nix ];
}
