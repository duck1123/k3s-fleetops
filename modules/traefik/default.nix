{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "traefik";

  # https://artifacthub.io/packages/helm/traefik/traefik
  chart = lib.helm.downloadHelmChart {
    repo = "https://traefik.github.io/charts";
    chart = "traefik";
    version = "35.0.0";
    chartHash = "sha256-fY34pxXS/Uyvpcl0TmV6dIlrItLMKlNK1FEPmjsWr4M=";
  };

  defaultValues = cfg: {
    # providers.kubernetesGateway.statusAddress.hostname = "localhost";
    additionalArguments = [
      "--entryPoints.web.forwardedHeaders.insecure=true"
      "--entryPoints.web.proxyProtocol.insecure=true"
      "--entryPoints.web.transport.respondingTimeouts.readTimeout=600s"
      "--entryPoints.web.transport.respondingTimeouts.writeTimeout=600s"
      "--entryPoints.web.transport.respondingTimeouts.idleTimeout=600s"
    ];
  };

  extraConfig = cfg: { nixidy.resourceImports = [ ./generated.nix ]; };
}
