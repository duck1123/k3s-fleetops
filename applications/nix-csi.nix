{ ... }:
{
  flake.nixidyApps.nix-csi =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    with lib;
    let
      nixcsi = import "${self.inputs.nix-csi}/default.nix" {
        system = pkgs.stdenv.hostPlatform.system;
      };
    in
    self.lib.mkArgoApp
      {
        inherit config lib self pkgs;
      }
      {
        name = "nix-csi";
        namespace = "nix-csi";

        extraOptions = {
          authorizedKeys = mkOption {
            description = mdDoc "SSH public keys authorized to connect to nix-csi cache/builders";
            type = types.listOf types.str;
            default = [ ];
          };

          cache.storageClassName = mkOption {
            description = mdDoc "Storage class for nix-csi cache PVC (null = cluster default)";
            type = types.nullOr types.str;
            default = null;
          };
        };

        extraAppConfig =
          cfg:
          let
            nixcsiEval = nixcsi.kubenixInstance {
              module.imports = [
                # Override curPkgs to avoid builtins.currentSystem (unavailable in pure eval)
                { _module.args.curPkgs = mkForce nixcsi.pkgs; }
                {
                  nix-csi = {
                    authorizedKeys = cfg.authorizedKeys;
                    cache.storageClassName = cfg.cache.storageClassName;
                  };
                }
              ];
            };

            resources = nixcsiEval.eval.config.kubernetes.generated;
            yaml = builtins.unsafeDiscardStringContext (
              builtins.concatStringsSep "\n---\n" (map builtins.toJSON resources)
            );
          in
          {
            # Deploy nix-csi before other apps that use the CSI driver (wave 0).
            # ArgoCD waits for wave -1 to be healthy before starting wave 0.
            annotations."argocd.argoproj.io/sync-wave" = "-1";
            yamls = [ yaml ];
          };
      };
}
