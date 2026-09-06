{ ... }:
{
  # mkArgoApp
  #
  # Takes the current config and lib and returns a function that creates a nixidy application with defaults
  flake.lib.mkArgoApp =
    {
      config,
      lib,
      self ? null,
      # The default storageClassName for this application
      storageClassName ? "longhorn",
      # The default timezone for this application
      tz ? "Etc/UTC",
      pkgs ? null,
      ...
    }:
    {
      # The name of the application (string)
      name,
      namespace ? null,
      # The chart to deploy (path)
      chart ? null,
      # A function that takes the config and returns default helm chart values
      defaultValues ? (cfg: { }),
      # A list of secrets that need to be loaded when generating this application
      neededSecrets ? [ ],
      # A function that takes the config and returns extra config merged into the app release.
      extraAppConfig ? (cfg: { }),
      # A function that takes the config and returns extra config merged into final config
      extraConfig ? (cfg: { }),
      # Additional config options
      extraOptions ? { },
      # A function that takes the config and returns extra resources to deploy with the application
      extraResources ? (cfg: { }),
      # A function that takes the config and returns an attrset of pinned-volume specs, keyed by a
      # short logical volume name (e.g. "appdata", "config") -- each value is the arg-set for
      # `self.lib.mkPinnedVolume` minus `pvcName` (that's derived as "${name}-${name}-<key>" to
      # match this repo's existing naming convention). See docs/pinned-volumes.md.
      pinnedVolumes ? (cfg: { }),
      # A function that takes the config and returns secrets to encrypt (name -> stringData attrs)
      sopsSecrets ? (cfg: { }),
      # Does this chart expose an ingress
      uses-ingress ? false,
      # Does this app have a centralized NFS mount (services.<name>.nfs.*)
      uses-nfs ? false,
      # Does this app have a centralized external database (services.<name>.database.*)
      uses-database ? false,
    }:
    with lib;
    let
      inherit (types)
        attrs
        listOf
        nullOr
        path
        str
        submodule
        unspecified
        ;
      cfg = config.services.${name};
      values = attrsets.recursiveUpdate (defaultValues cfg) cfg.values;

      # See docs/pinned-volumes.md. `resolvedPinnedVolumes` is whatever the app's
      # `pinnedVolumes cfg` returned; `pinnedVolumeFragments` runs each one through
      # `mkPinnedVolume` (producing that entry's { persistentVolumeClaims; persistentVolumes; });
      # `pinnedVolumeResources` folds all of those into one attrset merged into this app's
      # resources automatically. `pinnedVolumeInfo` (exposed as `cfg.pinnedVolumes`) is what
      # extraResources/extraAppConfig/etc reference instead of hand-typing the PVC name --
      # `cfg.pinnedVolumes.<key>.volume` is a ready `{ name; persistentVolumeClaim.claimName; }`
      # for a Deployment's `spec.template.spec.volumes`.
      resolvedPinnedVolumes = pinnedVolumes cfg;
      pinnedVolumePvcName = volName: "${name}-${name}-${volName}";
      pinnedVolumeFragments = lib.mapAttrs (
        volName: args: self.lib.mkPinnedVolume ({ pvcName = pinnedVolumePvcName volName; } // args)
      ) resolvedPinnedVolumes;
      pinnedVolumeResources = lib.foldl' lib.recursiveUpdate { } (lib.attrValues pinnedVolumeFragments);
      pinnedVolumeInfo = lib.mapAttrs (volName: _: {
        pvcName = pinnedVolumePvcName volName;
        volume = {
          name = volName;
          persistentVolumeClaim.claimName = pinnedVolumePvcName volName;
        };
      }) resolvedPinnedVolumes;

      # Combined secrets from sopsSecrets parameter and cfg.sopsSecrets option (option overrides)
      combinedSopsSecrets = (sopsSecrets cfg) // cfg.sopsSecrets;

      # Secret specs (with plaintext values) for write-sops-secrets.sh to encrypt outside Nix.
      # Never passed to a derivation — accessed only via `nix eval` so values never enter the store.
      secretSpecsList =
        if combinedSopsSecrets == { } then
          [ ]
        else
          lib.mapAttrsToList (secretName: data: {
            inherit secretName;
            app = name;
            namespace = cfg.namespace;
            values = if data ? values then data.values else data;
          }) combinedSopsSecrets;

      # Inject hostAffinity nodeSelector into all deployment and statefulSet pod specs
      addHostAffinityToResources =
        resources: hostAffinity:
        if hostAffinity == null then
          resources
        else
          let
            nodeSelectorFragment = {
              "kubernetes.io/hostname" = hostAffinity;
            };
            addToPodSpec =
              spec:
              spec
              // {
                nodeSelector = (spec.nodeSelector or { }) // nodeSelectorFragment;
              };
            addToWorkload =
              workload:
              workload
              // {
                spec = (workload.spec or { }) // {
                  template = (workload.spec.template or { }) // {
                    spec = addToPodSpec (workload.spec.template.spec or { });
                  };
                };
              };
          in
          resources
          // {
            deployments = lib.mapAttrs (_: addToWorkload) (resources.deployments or { });
            statefulSets = lib.mapAttrs (_: addToWorkload) (resources.statefulSets or { });
          };
      tls-options = {
        enable = mkEnableOption "Enable application";

        secretName = mkOption {
          description = mdDoc "The domain to expost ${name} to";
          type = str;
          default = "${name}-tls";
        };
      };
      ingress-options = {
        clusterIssuer = mkOption {
          description = mdDoc "The cluster issuer to use for ${name}'s tls";
          type = str;
          default = "letsEncrypt-prod";
        };

        domain = mkOption {
          description = mdDoc "The domain to expost ${name} to";
          type = str;
          default = "${name}.local";
        };

        ingressClassName = mkOption {
          description = mdDoc ''
            Ingress class: `traefik` for the in-cluster Traefik controller (often exposed with `Service` type LoadBalancer and MetalLB), or `tailscale` for the Tailscale Kubernetes operator.
          '';
          type = str;
          default = "traefik";
        };

        tls = tls-options;
      };
      nfs-options = {
        enable = mkEnableOption "an NFS mount for ${name}";

        server = mkOption {
          description = mdDoc "NFS server hostname/IP.";
          type = str;
          default = "";
        };

        path = mkOption {
          description = mdDoc "NFS server path.";
          type = str;
          default = "";
        };
      };
      database-options = {
        enable = mkEnableOption "an external database for ${name}";

        host = mkOption {
          description = mdDoc "Database host.";
          type = str;
          default = "";
        };

        port = mkOption {
          description = mdDoc "Database port.";
          type = types.port;
          default = 0;
        };

        name = mkOption {
          description = mdDoc "Database name.";
          type = str;
          default = name;
        };

        username = mkOption {
          description = mdDoc "Database username.";
          type = str;
          default = name;
        };

        password = mkOption {
          description = mdDoc "Database password.";
          type = str;
          default = "";
        };
      };
      basic-options = {
        chart = mkOption {
          type = nullOr path;
          default = chart;
          description = "Helm chart to use for ${name}.";
        };

        enable = mkEnableOption "Enable ${name} app";

        extraAppConfig = mkOption {
          default = { };
          description = "Extra config merged into the app release.";
          type = attrs;
        };

        extraResources = mkOption {
          default = { };
          description = "Extra Kubernetes resources related to ${name}.";
          type = attrs;
        };

        hostAffinity = mkOption {
          description = mdDoc "The host to assign the node to";
          type = nullOr types.str;
          default = null;
        };

        ingressProvider = mkOption {
          description = mdDoc "Name of a config.ingressProviders entry supplying default ingress.{ingressClassName,clusterIssuer,domain} for ${name}.";
          type = nullOr str;
          default = null;
        };

        nfsTarget = mkOption {
          description = mdDoc "Name of a config.nfsTargets entry supplying default nfs.{server,path} for ${name}.";
          type = nullOr str;
          default = "nas";
        };

        nfsSubPath = mkOption {
          description = mdDoc "Path appended to the nfsTarget's basePath to form nfs.path.";
          type = types.str;
          default = "";
        };

        databaseTarget = mkOption {
          description = mdDoc "Name of a config.databaseProviders entry supplying default database.{host,port,username,password} for ${name}.";
          type = nullOr str;
          default = null;
        };

        libvaDriverName = mkOption {
          description = mdDoc "LIBVA_DRIVER_NAME for VAAPI (e.g. iris for Intel, radeonsi for AMD). Auto-derived from hostAffinity via nodeGpuProfiles. Empty string = do not set.";
          type = types.str;
          default = "";
        };

        vaapiRenderDevice = mkOption {
          description = mdDoc "Host DRI render device (e.g. renderD129) to mount as /dev/dri/renderD128. Auto-derived from hostAffinity. Empty = mount entire /dev/dri.";
          type = types.str;
          default = "";
        };

        renderGroupGID = mkOption {
          description = mdDoc "GID of the host render group for /dev/dri access. Auto-derived from hostAffinity (default 303 on NixOS).";
          type = types.int;
          default = 303;
        };

        ingress = mkOption {
          apply =
            val:
            assert uses-ingress || val == { };
            val;
          default = { };
          description = "Ingress Options";
          type =
            if uses-ingress then
              submodule (
                let
                  extra-ingress = extraOptions.ingress or { };
                  options = recursiveUpdate ingress-options extra-ingress;
                in
                {
                  inherit options;
                }
              )
            else
              unspecified;
        };

        namespace = mkOption {
          description = mdDoc "The namespace to install ${name} into";
          type = str;
          default = if namespace != null then namespace else name;
        };

        # Read by the `autokuma` app, which collects one entry per service where
        # this is enabled into a static AutoKuma monitor file — see
        # applications/autokuma.nix. Defaults to on for any app with an ingress
        # (opt out per-app with `monitoring.autokuma.enable = false;`); apps
        # without an ingress still default off since there's no URL to probe.
        monitoring.autokuma = {
          enable = mkOption {
            description = mdDoc "Enable an AutoKuma-managed Uptime Kuma monitor for ${name}. Defaults to true when ${name} has an ingress.";
            type = types.bool;
            default = uses-ingress;
          };

          type = mkOption {
            description = mdDoc "AutoKuma monitor type (see upstream ENTITY_TYPES.md: http, tcp, ping, port, ...).";
            type = str;
            default = "http";
          };

          url = mkOption {
            description = mdDoc "URL used for http-type monitors. Defaults to this app's ingress domain when it has one.";
            type = nullOr str;
            default = if uses-ingress then "https://${cfg.ingress.domain}" else null;
          };

          displayName = mkOption {
            description = mdDoc "Monitor name shown in Uptime Kuma.";
            type = str;
            default = name;
          };

          extraSettings = mkOption {
            description = mdDoc "Extra fields merged into the generated AutoKuma monitor definition (e.g. port, hostname, retries, tag_names).";
            type = attrs;
            default = { };
          };
        };

        # Read by the `homepage` app, which collects one entry per service where
        # this is enabled into a services.yaml dashboard group — see
        # applications/homepage.nix. Defaults to on for any app with an ingress
        # (opt out per-app with `homepage.enable = false;`); apps without an
        # ingress default off since there's no href to link to.
        homepage = {
          enable = mkOption {
            description = mdDoc "Show ${name} as a link on the homepage dashboard. Defaults to true when ${name} has an ingress.";
            type = types.bool;
            default = uses-ingress;
          };

          group = mkOption {
            description = mdDoc "Dashboard group/category ${name} is listed under. Must be one of `config.homepageGroups` (see modules/homepageGroups.nix) -- add new groups there first.";
            type = types.enum config.homepageGroups;
            default = "Apps";
          };

          displayName = mkOption {
            description = mdDoc "Name shown on the dashboard tile.";
            type = str;
            default = name;
          };

          icon = mkOption {
            description = mdDoc "Dashboard icon (dashboard-icons name, Simple Icons slug, or full URL). Empty = no icon.";
            type = str;
            default = "";
          };

          description = mkOption {
            description = mdDoc "Text shown under the tile name on the dashboard.";
            type = str;
            default = "";
          };

          href = mkOption {
            description = mdDoc "Link target. Defaults to this app's ingress URL when it has one.";
            type = nullOr str;
            default = if uses-ingress then "https://${cfg.ingress.domain}" else null;
          };

          extraSettings = mkOption {
            description = mdDoc "Extra fields merged into the generated dashboard item (e.g. widget, siteMonitor, ping).";
            type = attrs;
            default = { };
          };
        };

        neededSecrets = mkOption {
          type = listOf str;
          default = neededSecrets;
          description = "List of secrets needed by ${name}.";
        };

        # Attrset of secrets to encrypt. Key = secret name, value = stringData attrs (or { values = attrs }).
        # Encryption happens outside Nix via scripts/write-sops-secrets.sh so plaintext never enters the store.
        sopsSecrets = mkOption {
          default = { };
          description = mdDoc "Secrets to encrypt. Key = secret name, value = stringData attrs (or { values = attrs }).";
          type = types.attrsOf types.anything;
        };

        # Internal: populated by mkArgoApp for CI manifest (list of { app, secretName, namespace, keys }).
        sopsSecretsManifest = mkOption {
          default = [ ];
          type = types.listOf types.attrs;
          internal = true;
          description = "Secret manifest entries for this app (for CI).";
        };

        # Internal: full secret specs with plaintext values for write-sops-secrets.sh.
        # Exposed via `nix eval` only — never built as a derivation, never in the Nix store.
        sopsSecretsSpec = mkOption {
          default = [ ];
          type = types.listOf types.attrs;
          internal = true;
          description = "Full secret specs (secretName, namespace, values) for external sops encryption.";
        };

        storageClassName = mkOption {
          description = mdDoc "The storage class";
          type = types.str;
          default = storageClassName;
        };

        # Internal: computed from the outer `pinnedVolumes` parameter -- see
        # docs/pinned-volumes.md. Reference `cfg.pinnedVolumes.<key>.volume` in a
        # Deployment's `volumes` list instead of hand-typing the PVC name; the
        # matching PersistentVolumeClaim/PersistentVolume resources are already
        # merged into this app automatically.
        pinnedVolumes = mkOption {
          internal = true;
          default = pinnedVolumeInfo;
          type = types.attrsOf types.attrs;
          description = mdDoc "Computed pinned-volume info (`.pvcName`, `.volume`), one entry per key in the `pinnedVolumes` parameter passed to mkArgoApp.";
        };

        tz = mkOption {
          description = mdDoc "The timezone";
          type = types.str;
          default = tz;
        };

        values = mkOption {
          description = "All the values";
          type = types.attrsOf types.anything;
          default = { };
        };
      }
      // lib.optionalAttrs uses-nfs {
        nfs = mkOption {
          default = { };
          description = "NFS Options";
          type = submodule (
            let
              extra-nfs = extraOptions.nfs or { };
              options = recursiveUpdate nfs-options extra-nfs;
            in
            {
              inherit options;
            }
          );
        };
      }
      // lib.optionalAttrs uses-database {
        database = mkOption {
          default = { };
          description = "Database Options";
          type = submodule (
            let
              extra-database = extraOptions.database or { };
              options = recursiveUpdate database-options extra-database;
            in
            {
              inherit options;
            }
          );
        };
      };
    in
    {
      options.services.${name} = lib.foldl' lib.recursiveUpdate { } [
        basic-options
        extraOptions
      ];

      config = mkIf cfg.enable (
        mkMerge (
          [
            (mkIf (cfg.hostAffinity != null) (
              let
                profile = config.nodeGpuProfiles.${cfg.hostAffinity} or { };
              in
              {
                services.${name} = {
                  libvaDriverName = mkDefault (profile.libvaDriverName or "");
                  vaapiRenderDevice = mkDefault (profile.vaapiRenderDevice or "");
                  renderGroupGID = mkDefault (profile.renderGroupGID or 303);
                };
              }
            ))
          ]
          ++ lib.optional uses-ingress (
            mkIf (cfg.ingressProvider != null) (
              let
                profile = config.ingressProviders.${cfg.ingressProvider} or { };
              in
              {
                services.${name}.ingress = {
                  ingressClassName = mkDefault (profile.ingressClassName or "traefik");
                  clusterIssuer = mkDefault (profile.clusterIssuer or "letsEncrypt-prod");
                  domain = mkDefault "${name}.${profile.domain or "local"}";
                };
              }
            )
          )
          ++ lib.optional uses-nfs (
            mkIf (cfg.nfsTarget != null) (
              let
                t = config.nfsTargets.${cfg.nfsTarget} or { };
              in
              {
                services.${name}.nfs = {
                  server = mkDefault (t.server or "");
                  path = mkDefault (
                    if cfg.nfsSubPath != "" then "${t.basePath or ""}/${cfg.nfsSubPath}" else t.basePath or ""
                  );
                };
              }
            )
          )
          ++ lib.optional uses-database (
            mkIf (cfg.databaseTarget != null) (
              let
                t = config.databaseProviders.${cfg.databaseTarget} or { };
              in
              {
                services.${name}.database = {
                  host = mkDefault (t.host or "");
                  port = mkDefault (t.port or 0);
                  username = mkDefault ((t.usernameFor or (n: n)) name);
                  password = mkDefault ((t.passwordFor or (_: "")) name);
                };
              }
            )
          )
          ++ [
            (mkIf (combinedSopsSecrets != { }) {
              services.${name} = {
                sopsSecretsManifest = lib.mapAttrsToList (sn: data: {
                  app = name;
                  secretName = sn;
                  namespace = cfg.namespace;
                  keys = lib.attrNames (if data ? values then data.values else data);
                }) combinedSopsSecrets;
                sopsSecretsSpec = secretSpecsList;
              };
            })
            {
              # This is the application config for nixidy
              applications.${name} =
                let
                  # sopsSecrets are intentionally excluded: encryption happens outside Nix via
                  # scripts/write-sops-secrets.sh so plaintext values never enter the Nix store.
                  baseResources = lib.foldl' lib.recursiveUpdate { } [
                    pinnedVolumeResources
                    (extraResources cfg)
                    cfg.extraResources
                  ];
                  resources = addHostAffinityToResources (builtins.removeAttrs baseResources [
                    "sopsSecrets"
                  ]) cfg.hostAffinity;
                in
                mkMerge [
                  {
                    inherit (cfg) namespace;
                    createNamespace = true;
                    finalizer = "foreground";

                    # TODO: Should I be using some sort of overlay here?
                    inherit resources;
                    syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
                  }
                  (mkIf (cfg.chart != null) {
                    helm.releases.${name} = {
                      inherit values;
                      inherit (cfg) chart;
                    };
                  })
                  (extraAppConfig cfg)
                  cfg.extraAppConfig
                ];
            }
            (extraConfig cfg)
          ]
        )
      );
    };

}
