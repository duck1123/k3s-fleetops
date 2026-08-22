{ ... }:
{
  flake.nixidyApps.autokuma =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    with lib;
    let
      name = "autokuma";
      labels = {
        "app.kubernetes.io/name" = name;
        "app.kubernetes.io/instance" = name;
      };

      creds-secret = "autokuma-kuma-credentials";
      monitors-configmap = "autokuma-monitors";

      # autokuma is packaged upstream in nixpkgs (pkgs.autokuma) and its build
      # bundles the kuma-cli binary (`kuma`) alongside it — no packaging needed
      # here, just fetch a pinned nixpkgs at runtime like the other nix-csi apps.
      nixExpr = ''
        let
          pkgs = import (builtins.fetchTree {
            type = "github";
            owner = "nixos";
            repo = "nixpkgs";
            ref = "nixos-unstable";
          }) {};
        in
        pkgs.autokuma
      '';

      # Every mkArgoApp-based service exposes `monitoring.autokuma.*` (see
      # modules/lib/mkArgoApp.nix). Collect one static-monitor file per service
      # that both `enable`s itself and opts into monitoring, so this ConfigMap
      # (mounted as AutoKuma's `files` source) stays in sync with whatever this
      # repo currently has switched on.
      enabledMonitors = lib.filterAttrs (
        _: svc: (svc.enable or false) && (svc.monitoring.autokuma.enable or false)
      ) config.services;

      monitorData = lib.mapAttrs' (
        svcName: svc:
        let
          m = svc.monitoring.autokuma;
        in
        lib.nameValuePair "${svcName}.json" (
          builtins.toJSON (
            {
              inherit (m) type;
              name = m.displayName;
            }
            // lib.optionalAttrs (m.url != null) { inherit (m) url; }
            // m.extraSettings
          )
        )
      ) enabledMonitors;
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
          kuma.url = mkOption {
            description = mdDoc "Uptime Kuma URL (Socket.IO endpoint) AutoKuma connects to.";
            type = types.str;
            default = "http://uptime-kuma.uptime-kuma:3001";
          };

          kuma.username = mkOption {
            description = mdDoc "Uptime Kuma login username. Stored in a SOPS secret.";
            type = types.str;
            default = "";
          };

          kuma.password = mkOption {
            description = mdDoc "Uptime Kuma login password. Stored in a SOPS secret.";
            type = types.str;
            default = "";
          };

          healthcheckPort = mkOption {
            description = mdDoc "Port AutoKuma's own health-check/metrics HTTP server listens on.";
            type = types.int;
            default = 8090;
          };
        };

        sopsSecrets =
          cfg:
          optionalAttrs (cfg.kuma.username != "" && cfg.kuma.password != "") {
            ${creds-secret} = {
              USERNAME = cfg.kuma.username;
              PASSWORD = cfg.kuma.password;
            };
          };

        extraResources = cfg: {
          configMaps.${monitors-configmap}.data = monitorData;

          deployments.${name}.spec = {
            replicas = 1;
            selector.matchLabels = labels;
            template = {
              metadata.labels = labels;
              spec = {
                containers = [
                  {
                    inherit name;
                    image = "ghcr.io/lillecarl/nix-csi/scratch:1.0.1";
                    command = [ "autokuma" ];
                    env = [
                      {
                        name = "AUTOKUMA__KUMA__URL";
                        value = cfg.kuma.url;
                      }
                      {
                        name = "AUTOKUMA__DOCKER__ENABLED";
                        value = "false";
                      }
                      {
                        name = "AUTOKUMA__KUBERNETES__ENABLED";
                        value = "false";
                      }
                      {
                        name = "AUTOKUMA__STATIC_MONITORS";
                        value = "/data/monitors";
                      }
                      {
                        name = "AUTOKUMA__ON_DELETE";
                        value = "delete";
                      }
                      {
                        name = "AUTOKUMA__HEALTHCHECK_PORT";
                        value = toString cfg.healthcheckPort;
                      }
                      {
                        name = "SSL_CERT_FILE";
                        value = "/nix/var/result/etc/ssl/certs/ca-bundle.crt";
                      }
                    ]
                    ++ optionals (cfg.kuma.username != "" && cfg.kuma.password != "") [
                      {
                        name = "AUTOKUMA__KUMA__USERNAME";
                        valueFrom.secretKeyRef = {
                          name = creds-secret;
                          key = "USERNAME";
                        };
                      }
                      {
                        name = "AUTOKUMA__KUMA__PASSWORD";
                        valueFrom.secretKeyRef = {
                          name = creds-secret;
                          key = "PASSWORD";
                        };
                      }
                    ];
                    # AutoKuma's healthcheck port only opens once its startup sync against
                    # Kuma (reconciling every existing monitor, since AUTOKUMA__ON_DELETE=delete)
                    # has completed, which can take well over the old liveness budget
                    # (120s + 3*30s = 210s) and got the container killed mid-sync every
                    # time, before it ever bound port 8090. A startupProbe gives that first
                    # sync a much bigger window; liveness/readiness only start counting once
                    # it succeeds once.
                    startupProbe = {
                      tcpSocket.port = cfg.healthcheckPort;
                      initialDelaySeconds = 10;
                      periodSeconds = 10;
                      timeoutSeconds = 5;
                      failureThreshold = 60; # 10s + 60*10s = ~10min budget for first sync
                    };
                    readinessProbe = {
                      tcpSocket.port = cfg.healthcheckPort;
                      periodSeconds = 10;
                      timeoutSeconds = 5;
                      failureThreshold = 6;
                    };
                    livenessProbe = {
                      tcpSocket.port = cfg.healthcheckPort;
                      periodSeconds = 30;
                      timeoutSeconds = 5;
                      failureThreshold = 3;
                    };
                    volumeMounts = [
                      {
                        name = "nix";
                        mountPath = "/nix";
                        subPath = "nix";
                      }
                      {
                        name = "monitors";
                        mountPath = "/data/monitors";
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
                    name = "monitors";
                    configMap.name = monitors-configmap;
                  }
                ];
              };
            };
          };
        };
      };
}
