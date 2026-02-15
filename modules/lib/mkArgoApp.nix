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
      # A function that takes the config and returns secrets to create via createSecret (name -> stringData attrs)
      sopsSecrets ? (cfg: { }),
      # Does this chart expose an ingress
      uses-ingress ? false,
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

      # Combined secrets from sopsSecrets parameter and cfg.sopsSecrets option (option overrides)
      combinedSopsSecrets = (sopsSecrets cfg) // cfg.sopsSecrets;

      # Expand combinedSopsSecrets (name -> data) into createSecret results when self and pkgs are available
      expandedSopsSecrets =
        if combinedSopsSecrets != { } && self != null && pkgs != null then
          lib.mapAttrs (
            secretName: data:
            self.lib.createSecret {
              ageRecipients = config.ageRecipients;
              namespace = cfg.namespace;
              inherit pkgs secretName;
              values = if data ? values then data.values else data;
            }
          ) combinedSopsSecrets
        else
          { };

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
          description = mdDoc "The name of the ingress class to use";
          type = str;
          default = "traefik";
        };

        tls = tls-options;
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

        # Attrset of secrets to create via createSecret. Key = secret name, value = stringData
        # attrs or { values = attrs }. createSecret is called with defaults: namespace =
        # cfg.namespace, ageRecipients = config.ageRecipients. Pass self and pkgs to
        # mkArgoApp when using this option.
        sopsSecrets = mkOption {
          default = { };
          description = mdDoc "Secrets to create via createSecret. Key = secret name, value = stringData attrs (or { values = attrs }).";
          type = types.attrsOf types.anything;
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
        {
          # This is the application config for nixidy
          applications.${name} =
            let
              baseResources = lib.recursiveUpdate (extraResources cfg) cfg.extraResources;
              resourcesWithSops = baseResources // {
                sopsSecrets = (baseResources.sopsSecrets or { }) // expandedSopsSecrets;
              };
              resources = addHostAffinityToResources resourcesWithSops cfg.hostAffinity;
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
