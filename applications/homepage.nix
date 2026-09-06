{ ... }:
{
  flake.nixidyApps.homepage =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    with lib;
    let
      name = "homepage";
      labels = {
        "app.kubernetes.io/instance" = name;
        "app.kubernetes.io/name" = name;
      };
      config-configmap = "${name}-config";

      # Every mkArgoApp-based service exposes `homepage.*` (see
      # modules/lib/mkArgoApp.nix). Collect one dashboard item per service that
      # both `enable`s itself and opts into the dashboard, grouped by
      # `homepage.group`, so this stays in sync with whatever's switched on —
      # no manual link list to maintain alongside each app.
      discoveredGroups =
        lib.foldl'
          (
            acc: svc:
            let
              h = svc.homepage;
              item = {
                inherit (h) href;
              }
              // lib.optionalAttrs (h.icon != "") { inherit (h) icon; }
              // lib.optionalAttrs (h.description != "") { inherit (h) description; }
              // h.extraSettings;
            in
            lib.recursiveUpdate acc {
              ${h.group} = {
                ${h.displayName} = item;
              };
            }
          )
          { }
          (
            lib.filter (svc: (svc.enable or false) && (svc.homepage.enable or false)) (
              lib.attrValues config.services
            )
          );
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
        uses-ingress = true;

        # Secret plaintext must never flow through `self.lib.toYAML` (it round-trips
        # through the Nix store via `builtins.toFile`/`pkgs.runCommand`, which would
        # leave API keys world-readable in /nix/store). Instead each `widgetSecrets`
        # entry becomes its own key in a sops-encrypted Kubernetes Secret (via the
        # existing write-sops-secrets.sh pipeline) and is injected as a
        # `HOMEPAGE_VAR_<KEY>` env var. Reference it from `settings`/`widgets`/
        # `extraGroups`/`bookmarkGroups` with homepage's own substitution syntax,
        # e.g. `key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";` -- homepage resolves the
        # placeholder from the env var at render time, so the plaintext value never
        # appears in the ConfigMap or in git. See https://gethomepage.dev/configs/secrets/
        sopsSecrets =
          cfg:
          lib.optionalAttrs (cfg.widgetSecrets != { }) {
            "${name}-widget-secrets" = cfg.widgetSecrets;
          };

        extraOptions = {
          image = mkOption {
            description = mdDoc "The homepage docker image";
            type = types.str;
            default = "ghcr.io/gethomepage/homepage:latest";
          };

          replicas = mkOption {
            description = mdDoc "Number of replicas";
            type = types.int;
            default = 1;
          };

          settings = mkOption {
            description = mdDoc "Raw contents of settings.yaml (title, theme, layout, ...). See https://gethomepage.dev/configs/settings/";
            type = types.attrs;
            default = {
              title = "Homelab";
              theme = "dark";
            };
          };

          extraGroups = mkOption {
            description = mdDoc ''
              Extra/override dashboard groups merged with the ones auto-discovered from
              `services.<name>.homepage.*`. Shape: `{ "Group Name".itemName = { href = "..."; icon = "..."; }; }`.
              Use this for links that aren't a mkArgoApp service (e.g. router admin page, NAS UI).
            '';
            type = types.attrsOf (types.attrsOf types.attrs);
            default = { };
          };

          bookmarkGroups = mkOption {
            description = mdDoc ''
              Contents of bookmarks.yaml. Shape: `{ "Group Name".bookmarkName = { href = "..."; abbr = "XX"; icon = "..."; }; }`.
              See https://gethomepage.dev/configs/bookmarks/
            '';
            type = types.attrsOf (types.attrsOf types.attrs);
            default = { };
          };

          widgets = mkOption {
            description = mdDoc "Raw contents of widgets.yaml (info widgets like search/resources/datetime). See https://gethomepage.dev/configs/info-widgets/";
            type = types.listOf types.attrs;
            default = [ ];
          };

          extraAllowedHosts = mkOption {
            description = mdDoc "Extra hostnames to add to HOMEPAGE_ALLOWED_HOSTS beyond this app's own ingress domain(s).";
            type = types.listOf types.str;
            default = [ ];
          };

          widgetSecrets = mkOption {
            description = mdDoc ''
              API keys/passwords for widgets (e.g. a service's `widget.key`), keyed by
              the name you'll reference as `{{HOMEPAGE_VAR_<KEY>}}` inside `settings`,
              `widgets`, `extraGroups`, or `bookmarkGroups`. Each entry is written to a
              sops-encrypted Kubernetes Secret (never the ConfigMap) and exposed to the
              container as a `HOMEPAGE_VAR_<KEY>` env var that homepage substitutes at
              render time. Set real values in `env/dev/homepage.nix` from
              `secrets.homepage.widgets.<key>` in secrets.enc.yaml -- never inline a
              plaintext key/password directly in `widgets`/`extraGroups` here.
            '';
            type = types.attrsOf types.str;
            default = { };
          };
        };

        extraResources =
          cfg:
          let
            finalGroups = lib.recursiveUpdate discoveredGroups cfg.extraGroups;

            # Render groups in `config.homepageGroups` order (that's what
            # controls left-to-right/top-to-bottom dashboard placement --
            # see modules/homepageGroups.nix) rather than the alphabetical
            # order `finalGroups`' attrset keys would otherwise iterate in.
            # Any group name not in the registry (there shouldn't be one,
            # short of a stray `extraGroups` typo) still renders, just after
            # the known ones.
            orderedGroupNames =
              config.homepageGroups ++ lib.subtractLists config.homepageGroups (lib.attrNames finalGroups);

            servicesYaml = map (groupName: {
              ${groupName} = lib.mapAttrsToList (itemName: item: {
                ${itemName} = item;
              }) finalGroups.${groupName};
            }) (lib.filter (groupName: finalGroups ? ${groupName}) orderedGroupNames);

            bookmarksYaml = lib.mapAttrsToList (groupName: items: {
              ${groupName} = lib.mapAttrsToList (itemName: item: { ${itemName} = [ item ]; }) items;
            }) cfg.bookmarkGroups;

            allowedHosts = [ cfg.ingress.domain ] ++ cfg.extraAllowedHosts;
          in
          {
            configMaps.${config-configmap}.data = {
              "settings.yaml" = self.lib.toYAML {
                inherit pkgs;
                value = cfg.settings;
              };
              "services.yaml" = self.lib.toYAML {
                inherit pkgs;
                value = servicesYaml;
              };
              "bookmarks.yaml" = self.lib.toYAML {
                inherit pkgs;
                value = bookmarksYaml;
              };
              "widgets.yaml" = self.lib.toYAML {
                inherit pkgs;
                value = cfg.widgets;
              };
            };

            deployments.${name} = {
              metadata.labels = labels // {
                "app.kubernetes.io/version" = "latest";
              };

              spec = {
                replicas = cfg.replicas;
                strategy.type = "Recreate";
                selector.matchLabels = labels;

                template = {
                  metadata.labels = labels;
                  spec = {
                    initContainers = [
                      {
                        name = "config-init";
                        image = cfg.image;
                        imagePullPolicy = "IfNotPresent";
                        # homepage lazily copies its own bundled skeleton default
                        # for whatever config file it needs the first time it's
                        # asked for one (kubernetes.yaml, docker.yaml, custom.css,
                        # custom.js, proxmox.yaml, ... -- an open-ended and
                        # version-dependent list, confirmed by it crashing on a
                        # different missing file each time one was pre-empted).
                        # Rather than chase that list, seed a writable /app/config
                        # from the image's own skeleton, then overlay only the
                        # files we actually manage from the read-only ConfigMap.
                        command = [
                          "sh"
                          "-c"
                          "cp -r /app/src/skeleton/. /app/config/ && cp -f /config-src/*.yaml /app/config/"
                        ];
                        volumeMounts = [
                          {
                            name = "config";
                            mountPath = "/app/config";
                          }
                          {
                            name = "config-src";
                            mountPath = "/config-src";
                            readOnly = true;
                          }
                        ];
                      }
                    ];

                    containers = [
                      {
                        inherit name;
                        image = cfg.image;
                        imagePullPolicy = "IfNotPresent";
                        env = [
                          {
                            name = "TZ";
                            value = cfg.tz;
                          }
                          {
                            name = "HOMEPAGE_ALLOWED_HOSTS";
                            value = lib.concatStringsSep "," allowedHosts;
                          }
                        ]
                        ++ lib.mapAttrsToList (key: _: {
                          name = "HOMEPAGE_VAR_${key}";
                          valueFrom.secretKeyRef = {
                            name = "${name}-widget-secrets";
                            inherit key;
                          };
                        }) cfg.widgetSecrets;
                        ports = [
                          {
                            containerPort = 3000;
                            name = "http";
                            protocol = "TCP";
                          }
                        ];
                        readinessProbe = {
                          httpGet = {
                            path = "/";
                            port = 3000;
                            # kubelet's probe connects straight to the pod IP, which
                            # HOMEPAGE_ALLOWED_HOSTS rejects (it validates the Host
                            # header, not the actual origin). Override it to a value
                            # homepage allows by default rather than adding a
                            # per-pod-IP entry to the allowlist.
                            httpHeaders = [
                              {
                                name = "Host";
                                value = "localhost:3000";
                              }
                            ];
                          };
                          initialDelaySeconds = 10;
                          periodSeconds = 10;
                          timeoutSeconds = 5;
                          successThreshold = 1;
                          failureThreshold = 3;
                        };
                        livenessProbe = {
                          httpGet = {
                            path = "/";
                            port = 3000;
                            httpHeaders = [
                              {
                                name = "Host";
                                value = "localhost:3000";
                              }
                            ];
                          };
                          initialDelaySeconds = 20;
                          periodSeconds = 30;
                          timeoutSeconds = 5;
                          successThreshold = 1;
                          failureThreshold = 3;
                        };
                        volumeMounts = [
                          {
                            name = "config";
                            mountPath = "/app/config";
                          }
                        ];
                      }
                    ];

                    volumes = [
                      {
                        # Writable -- seeded by the config-init initContainer from
                        # the image's own skeleton, then overlaid with our config.
                        name = "config";
                        emptyDir = { };
                      }
                      {
                        name = "config-src";
                        configMap.name = config-configmap;
                      }
                    ];
                  };
                };
              };
            };

            ingresses.${name} = with cfg.ingress; {
              metadata.annotations = optionalAttrs (clusterIssuer != "") {
                "cert-manager.io/cluster-issuer" = clusterIssuer;
              };

              spec = {
                inherit ingressClassName;

                rules = [
                  {
                    host = domain;

                    http.paths = [
                      {
                        backend.service = {
                          inherit name;
                          port.name = "http";
                        };

                        path = "/";
                        pathType = "ImplementationSpecific";
                      }
                    ];
                  }
                ];

                tls = [
                  {
                    hosts = [ domain ];
                    secretName = "${name}-tls";
                  }
                ];
              };
            };

            services.${name}.spec = {
              ports = [
                {
                  name = "http";
                  port = 3000;
                  protocol = "TCP";
                  targetPort = "http";
                }
              ];

              selector = labels;
              type = "ClusterIP";
            };
          };
      };
}
