{ ... }:
{
  flake.nixidyApps.demo =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    with lib;
    let
      name = "demo";
      labels = { "app.kubernetes.io/name" = name; };

      # ── Runtime ──────────────────────────────────────────────────────────────
      # nix-csi evaluates this expression on the node and mounts the result at
      # /nix so its bin directory is on PATH inside the scratch container.
      # Swap pkgs.python3 for any other nixpkgs derivation to change the runtime.
      serverExpr = ''
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

      # ── Server script ─────────────────────────────────────────────────────────
      # Stored in a ConfigMap so you can change server behaviour without touching
      # the runtime expression above.  Edit freely — standard Python, no deps.
      serverScript = ''
        import http.server
        import json
        import os
        import sys

        DATA_FILE = os.environ.get("JSON_DATA_FILE", "/data/data.json")
        PORT = int(os.environ.get("PORT", "8080"))


        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, fmt, *args):
                sys.stderr.write(fmt % args + "\n")
                sys.stderr.flush()

            def do_GET(self):
                try:
                    with open(DATA_FILE) as f:
                        body = f.read().encode()
                except Exception as exc:
                    body = json.dumps({"error": str(exc)}).encode()

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)


        print(f"json-server listening on :{PORT}", file=sys.stderr, flush=True)
        http.server.HTTPServer(("", PORT), Handler).serve_forever()
      '';
    in
    self.lib.mkArgoApp
      {
        inherit config lib self pkgs;
      }
      {
        name = "demo";

        extraOptions = {
          # ── Data ───────────────────────────────────────────────────────────────
          # Change this attrset (or override it in env/dev.nix) to serve different
          # JSON.  The value is serialised to /data/data.json inside the pod.
          jsonData = mkOption {
            description = mdDoc "JSON object served at GET /";
            type = types.attrs;
            default = {
              message = "Hello from nix-csi!";
              runtime = "python3";
            };
          };
        };

        extraResources =
          cfg:
          let
            port = 8080;
          in
          {
            configMaps = {
              demo-data.data."data.json" = builtins.toJSON cfg.jsonData;
              demo-server.data."server.py" = serverScript;
            };

            deployments.${name}.spec = {
              selector.matchLabels = labels;
              template = {
                metadata.labels = labels;
                spec = {
                  initContainers = [
                    {
                      name = "nix-debug";
                      image = "busybox:1.36";
                      command = [
                        "sh"
                        "-c"
                        ''
                          echo "=== /nix top-level ===" && ls -la /nix &&
                          echo "=== /nix/bin ===" && ls -la /nix/bin 2>/dev/null || echo "(no /nix/bin)" &&
                          echo "=== /nix/nix ===" && ls -la /nix/nix 2>/dev/null || echo "(no /nix/nix)" &&
                          echo "=== /nix/nix/var ===" && ls -la /nix/nix/var 2>/dev/null || echo "(no /nix/nix/var)" &&
                          echo "=== /nix/nix/var/result ===" && ls -la /nix/nix/var/result 2>/dev/null || echo "(no /nix/nix/var/result)" &&
                          echo "=== /nix/nix/store ===" && ls /nix/nix/store 2>/dev/null | head -20 || echo "(no /nix/nix/store)" &&
                          echo "=== all files 3 levels deep ===" && find /nix -maxdepth 3 2>/dev/null
                        ''
                      ];
                      volumeMounts = [
                        {
                          name = "nix";
                          mountPath = "/nix";
                        }
                      ];
                    }
                  ];
                  containers = [
                    {
                      inherit name;
                      image = "ghcr.io/lillecarl/nix-csi/scratch:1.0.1";
                      # nix-csi's deref_hardlink_tree copies the primary package to the volume
                      # root, so bin/ lands at /nix/bin/ (mountPath). The scratch image PATH
                      # (/nix/var/result/bin) points to the chroot symlink which resolves to an
                      # absolute host path not reachable inside the container, so use the direct path.
                      command = [ "/nix/bin/python3" "/scripts/server.py" ];
                      env = [
                        {
                          name = "PORT";
                          value = toString port;
                        }
                        {
                          name = "JSON_DATA_FILE";
                          value = "/data/data.json";
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
                        }
                        {
                          name = "scripts";
                          mountPath = "/scripts";
                        }
                        {
                          name = "data";
                          mountPath = "/data";
                        }
                      ];
                    }
                  ];
                  volumes = [
                    {
                      name = "nix";
                      csi = {
                        driver = "nix.csi.store";
                        volumeAttributes.nixExpr = serverExpr;
                      };
                    }
                    {
                      name = "scripts";
                      configMap.name = "demo-server";
                    }
                    {
                      name = "data";
                      configMap.name = "demo-data";
                    }
                  ];
                };
              };
            };

            services.${name}.spec = {
              selector = labels;
              ports = [
                {
                  name = "http";
                  port = 80;
                  targetPort = port;
                  protocol = "TCP";
                }
              ];
            };
          };
      };
}
