{ ... }:
{
  flake.modules.common.sopsConfig =
    { ... }:
    {
      sopsConfig = ../.sops.yaml;
    };
}
