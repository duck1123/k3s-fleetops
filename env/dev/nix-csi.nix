{ ... }:
{
  services.nix-csi.enable = true;
  services.nix-csi.cache.storageClassName = "longhorn";
}
