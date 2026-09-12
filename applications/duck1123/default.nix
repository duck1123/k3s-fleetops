{ ... }:
{
  flake.nixidyApps.duck1123 =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    with lib;
    let
      name = "duck1123";
      labels = {
        "app.kubernetes.io/name" = name;
      };

      # ── Runtime ──────────────────────────────────────────────────────────────
      # The site itself (pubkey, relays, NIP-05 well-known file) lives as a real
      # npm/Vite project at applications/duck1123-site/, built via the
      # `duck1123-site` flake package (modules/pkgs/duck1123-site.nix). Its
      # output store path is resolved right here at `nur switch` time (forcing
      # a local build of the site as part of the activation package) and baked
      # in literally via builtins.storePath -- so nix-csi never re-evaluates
      # the flake, and the embedded path only changes when the site's content
      # actually does. There's no fallback: builtins.storePath carries no build
      # recipe, so this exact path must be pushed to Attic (`attic push nixos
      # ${self.packages.x86_64-linux.duck1123-site}`) as part of every switch
      # that changes it, or nix-csi has nothing to substitute it from. It's
      # symlinkJoin'd with pkgs.python3 so /nix/var/result has both a
      # `bin/python3` to run server.py *and* the built static files
      # (index.html, assets/, .well-known/) at its root for that same server
      # to serve.
      nixExpr = ''
        let
          pkgs = import (builtins.fetchTree {
            type = "github";
            owner = "nixos";
            repo = "nixpkgs";
            ref = "nixos-unstable";
          }) {};
          site = builtins.storePath "${self.packages.x86_64-linux.duck1123-site}";
        in
        pkgs.symlinkJoin {
          name = "duck1123-runtime";
          paths = [
            pkgs.python3
            site
          ];
        }
      '';

      serverScript = builtins.readFile ./server.py;
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
        inherit name;

        extraResources =
          cfg:
          let
            port = 8080;
          in
          {
            configMaps.duck1123-server.data."server.py" = serverScript;

            deployments.${name}.spec = {
              selector.matchLabels = labels;
              template = {
                metadata.labels = labels;
                spec = {
                  containers = [
                    {
                      inherit name;
                      image = "ghcr.io/lillecarl/nix-csi/scratch:1.0.1";
                      command = [
                        "python3"
                        "/scripts/server.py"
                      ];
                      env = [
                        {
                          name = "PORT";
                          value = toString port;
                        }
                      ];
                      ports = [
                        {
                          containerPort = port;
                          name = "http";
                          protocol = "TCP";
                        }
                      ];
                      volumeMounts = [
                        {
                          name = "nix";
                          mountPath = "/nix";
                          subPath = "nix";
                        }
                        {
                          name = "scripts";
                          mountPath = "/scripts";
                        }
                      ];
                    }
                  ];
                  volumes = [
                    {
                      name = "nix";
                      csi = {
                        driver = "nix.csi.store";
                        volumeAttributes.nixExpr = nixExpr;
                      };
                    }
                    {
                      name = "scripts";
                      configMap.name = "duck1123-server";
                    }
                  ];
                };
              };
            };

            # No Ingress: the public route (duck1123.com) is a Cloudflare Tunnel
            # Public Hostname pointed at this Service's cluster-internal DNS name
            # (duck1123.duck1123.svc.cluster.local:8080), configured in the
            # Cloudflare dashboard against the `cloudflared` app's tunnel.
            services.${name}.spec = {
              selector = labels;
              ports = [
                {
                  name = "http";
                  port = port;
                  targetPort = port;
                  protocol = "TCP";
                }
              ];
            };
          };
      };
}
