{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "romm";
  uses-ingress = true;

  # https://artifacthub.io/packages/helm/retsamedoc/romm
  chart = helm.downloadHelmChart {
    repo = "https://retsamedoc.github.io/helm-charts";
    chart = "romm";
    version = "2025.3.1";
    chartHash = "sha256-z6o5LHUYqm7Jd5gsIs+J3Z48Frbj8F1ZnEZw4mHIeQA=";
  };

  defaultValues = cfg: {

  };
  
  
  extraResources = cfg: {
    ingresses.${name} = with cfg.ingress; {
      spec = {
        inherit ingressClassName;

        rules = [{
          host = domain;
          http.paths = [{
            backend.service = {
              inherit name;
              port.name = "http";
            };
            path = "/";
            pathType = "ImplementationSpecific";
          }];
        }];
        tls = [{ hosts = [ domain ]; }];
      };
    };

    persistentVolumeClaims = {
      "${name}-${name}-books".spec = {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
        storageClassName = "longhorn";
      };
      "${name}-${name}-config".spec = {
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
        storageClassName = "longhorn";
      };
    };

    services.${name}.spec = {
      ports = [{
        name = "http";
        port = 5000;
        protocol = "TCP";
        targetPort = "http";
      }];

      selector = {
        "app.kubernetes.io/instance" = name;
        "app.kubernetes.io/name" = name;
      };
      type = "ClusterIP";
    };
  };
}
