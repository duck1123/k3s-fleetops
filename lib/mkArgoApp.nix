# mkArgoApp
#
# Takes the current config and lib and returns a function that creates a nixidy application with defaults
{ config, lib, ... }:
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
      applications.${name} = mkMerge [
        {
          inherit (cfg) namespace;
          createNamespace = true;
          finalizer = "foreground";

          # TODO: Should I be using some sort of overlay here?
          resources = lib.recursiveUpdate (extraResources cfg) cfg.extraResources;
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
}
