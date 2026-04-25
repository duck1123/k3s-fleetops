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
      # A function that takes the config and returns secrets to encrypt (name -> stringData attrs)
      sopsSecrets ? (cfg: { }),
      # Does this chart expose an ingress
      uses-ingress ? false,
    }:
    with lib;
    let
      inherit (types)
        attrs
        int
        listOf
        nullOr
        oneOf
        path
        str
        submodule
        unspecified
        ;
      cfg = config.services.${name};
      values = attrsets.recursiveUpdate (defaultValues cfg) cfg.values;

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

        localIngress = {
          enable = mkEnableOption "Enable a local-only Traefik ingress for LAN access (requires *.local wildcard DNS → Traefik IP)";

          domain = mkOption {
            description = mdDoc "Local domain to expose ${name} on (e.g. ${name}.local)";
            type = str;
            default = "${name}.local";
          };

          serviceName = mkOption {
            description = mdDoc "Kubernetes Service name to route to. Defaults to the app name.";
            type = nullOr str;
            default = null;
          };

          servicePort = mkOption {
            description = mdDoc "Service port — a string selects a named port, an int selects by port number.";
            type = oneOf [
              str
              int
            ];
            default = "http";
          };

          tls.enable = mkEnableOption "Enable TLS on the local ingress";
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
      };
    in
    {
      options.services.${name} = lib.foldl' lib.recursiveUpdate { } [
        basic-options
        extraOptions
      ];

      config = mkIf cfg.enable (mkMerge [
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
              localIngressResources =
                if uses-ingress && cfg.ingress.localIngress.enable then
                  let
                    svcName =
                      if cfg.ingress.localIngress.serviceName != null then cfg.ingress.localIngress.serviceName else name;
                    svcPort =
                      let
                        p = cfg.ingress.localIngress.servicePort;
                      in
                      if builtins.isInt p then { number = p; } else { name = p; };
                  in
                  {
                    ingresses."${name}-local".spec = with cfg.ingress.localIngress; {
                      ingressClassName = "traefik";
                      rules = [
                        {
                          host = domain;
                          http.paths = [
                            {
                              backend.service = {
                                name = svcName;
                                port = svcPort;
                              };
                              path = "/";
                              pathType = "ImplementationSpecific";
                            }
                          ];
                        }
                      ];
                      tls = lib.optional tls.enable [ { hosts = [ domain ]; } ];
                    };
                  }
                else
                  { };
              # App's own resources take precedence over the auto-generated localIngress.
              # sopsSecrets are intentionally excluded: encryption happens outside Nix via
              # scripts/write-sops-secrets.sh so plaintext values never enter the Nix store.
              baseResources = lib.recursiveUpdate localIngressResources (
                lib.recursiveUpdate (extraResources cfg) cfg.extraResources
              );
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
      ]);
    };

}
