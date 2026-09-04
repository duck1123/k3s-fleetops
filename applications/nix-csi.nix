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
        inherit
          config
          lib
          self
          pkgs
          ;
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
            atticSettings = {
              substituters = [ "https://attic.home.kronkltd.net/nixos" ];
              trusted-public-keys = [ "nixos:6s8iAyKEnH2z4spigUdDmt1VwiAwrvPA9vQNUd9if1k=" ];
            };
            # Lets an authorizedKeys-holding SSH pusher (e.g. `nix copy --to ssh-ng://nix@...`)
            # add unsigned store paths directly — otherwise nix-daemon rejects them with
            # "lacks a signature by a trusted key", since attic normally provides signing.
            cacheSettings = atticSettings // {
              trusted-users = [ "nix" ];
            };
            nixcsiEval = nixcsi.kubenixInstance {
              module.imports = [
                # Override curPkgs to avoid builtins.currentSystem (unavailable in pure eval)
                { _module.args.curPkgs = mkForce nixcsi.pkgs; }
                {
                  nix-csi = {
                    authorizedKeys = cfg.authorizedKeys;
                    cache.storageClassName = cfg.cache.storageClassName;
                    # Bootstrap components (cache-init-env, proxy-env, etc.) aren't
                    # published to nix-csi.cachix.org for every commit — our own
                    # cache closes that gap so cold-starts don't depend on upstream CI.
                    cache.nixConfig.settings = cacheSettings;
                    node.nixConfig.settings = atticSettings;
                    builders.nixConfig.settings = atticSettings;
                  };
                }
              ];
            };

            resources = nixcsiEval.eval.config.kubernetes.generated;
            pinIp =
              ip: r:
              r
              // {
                metadata = r.metadata // {
                  annotations = (r.metadata.annotations or { }) // {
                    "metallb.universe.tf/loadBalancerIPs" = ip;
                  };
                };
              };
            patchedResources = map (
              r:
              if r.kind == "Service" && r.metadata.name == "nix-cache-lb" then
                pinIp "192.168.0.241" r
              else if r.kind == "Service" && r.metadata.name == "nix-proxy" then
                pinIp "192.168.0.240" r
              else
                r
            ) resources;
            yaml = builtins.unsafeDiscardStringContext (
              builtins.concatStringsSep "\n---\n" (map builtins.toJSON patchedResources)
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
