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
      # nix-csi evaluates this expression on the node and mounts the result at
      # /nix so its bin directory is on PATH inside the scratch container.
      nixExpr = ''
        let
          pkgs = import (builtins.fetchTree {
            type = "github";
            owner = "nixos";
            repo = "nixpkgs";
            ref = "nixos-unstable";
          }) {};
        in
        pkgs.python3
      '';

      # ── Site ─────────────────────────────────────────────────────────────────
      # Hand-written ES modules, no bundler/build step — nostr-tools is imported
      # at runtime from a pinned ESM CDN URL inside nostr.js. Every file here is
      # plain and can be edited freely without touching the Nix build, except
      # config.js which is generated below from `cfg.pubkey`/`cfg.relays`.
      siteFiles = {
        "index.html" = builtins.readFile ./site/index.html;
        "style.css" = builtins.readFile ./site/style.css;
        "nostr.js" = builtins.readFile ./site/nostr.js;
        "auth.js" = builtins.readFile ./site/auth.js;
        "comments.js" = builtins.readFile ./site/comments.js;
        "main.js" = builtins.readFile ./site/main.js;
      };

      configJs =
        cfg: ''
          export const CONFIG = {
            pubkey: ${builtins.toJSON cfg.pubkey},
            relays: ${builtins.toJSON cfg.relays},
          };
        '';
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

        extraOptions = {
          pubkey = mkOption {
            description = mdDoc "Hex nostr pubkey whose profile/notes this site displays";
            type = types.str;
            default = "47b38f4d3721390d5b6bef78dae3f3e3888ecdbf1844fbb33b88721d366d5c88";
          };

          relays = mkOption {
            description = mdDoc "Relay URLs the site queries for profile/notes and publishes replies to";
            type = types.listOf types.str;
            default = [
              "wss://relay.damus.io"
              "wss://nos.lol"
              "wss://relay.nostr.band"
              "wss://relay.primal.net"
            ];
          };
        };

        extraResources =
          cfg:
          let
            port = 8080;
          in
          {
            configMaps.duck1123-site.data = siteFiles // {
              "config.js" = configJs cfg;
            };

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
                        "-m"
                        "http.server"
                        (toString port)
                        "--directory"
                        "/site"
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
                          name = "site";
                          mountPath = "/site";
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
                      name = "site";
                      configMap.name = "duck1123-site";
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
