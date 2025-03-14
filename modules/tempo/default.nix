{ charts, config, lib, ... }:
let
  cfg = config.services.tempo;

  chart = lib.helm.downloadHelmChart {
    repo = "https://grafana.github.io/helm-charts";
    chart = "tempo";
    version = "1.15.0";
    chartHash = "sha256-hmshN4RoUb9GVoyEdPObzhMmsdLMnNMEdJXmhFzg8Lg=";
  };

  defaultNamespace = "tempo";
  domain = "tempo.dev.kronkltd.net";

  defaultValues = {
    persistence.enabled = true;
    tempo.retention = "72h";
    tempoQuery = {
      enabled = false;
      tag = "latest";
      ingress = {
        enabled = true;
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
          "ingress.kubernetes.io/force-ssl-redirect" = "true";
          "ingress.kubernetes.io/proxy-body-size" = "0";
          "ingress.kubernetes.io/ssl-redirect" = "true";
          "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure";
          "traefik.ingress.kubernetes.io/router.middlewares" =
            "authentik-middlewares-authenkik@kubernetescrd";
        };
        hosts = [ domain ];
        tls = [{
          secretName = "tempo-tls";
          hosts = [ domain ];
        }];
      };
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.tempo = {
    enable = mkEnableOption "Enable application";
    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = defaultNamespace;
    };

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    applications.tempo = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.tempo = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
