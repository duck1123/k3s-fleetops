{
  charts,
  config,
  lib,
  self,
  ...
}:
self.lib.mkArgoApp { inherit config lib; } {
  name = "traefik";

  # https://artifacthub.io/packages/helm/traefik/traefik
  chart = charts.traefik.traefik;

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
