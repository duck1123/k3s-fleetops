{
  config,
  lib,
  self,
  ...
}:
with lib;
self.lib.mkArgoApp { inherit config lib; } {
  name = "cloudbeaver";

  # https://artifacthub.io/packages/helm/avisto/cloudbeaver
  chart = helm.downloadHelmChart {
    repo = "https://avistotelecom.github.io/charts/";
    chart = "cloudbeaver";
    version = "1.0.4";
    chartHash = "sha256-sCaoErVyNTop9LwiomG9kVIBnVoKPpf0WIf24yam8pY=";
  };

  uses-ingress = true;

  extraOptions = {
    storageClass = mkOption {
      description = mdDoc "The storage class to use for persistence";
      type = types.str;
      default = "local-path";
    };
  };

  defaultValues = cfg: {
    ingress = with cfg.ingress; {
      inherit ingressClassName;

      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };

      enabled = true;
      hostname = domain;
      tls = true;
    };

    nodeSelector."kubernetes.io/hostname" = cfg.hostAffinity;

    persistence = {
      inherit (cfg) storageClass;
      enabled = true;
    };
  };
}
