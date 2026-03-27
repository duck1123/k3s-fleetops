{ ... }:
{
  flake.nixidyApps.traefik =
    {
      charts,
      config,
      crdImports,
      lib,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp { inherit config lib; } {
      name = "traefik";

      # https://artifacthub.io/packages/helm/traefik/traefik
      chart = charts.traefik.traefik;

      extraOptions = {
        service.type = mkOption {
          description = mdDoc "Traefik Service type. Use LoadBalancer with MetalLB so Ingress (ingressClassName: traefik) is reachable on a LAN VIP.";
          type = types.enum [
            "ClusterIP"
            "LoadBalancer"
            "NodePort"
          ];
          default = "LoadBalancer";
        };
      };

      defaultValues = cfg: {
        service.spec.type = cfg.service.type;
        # providers.kubernetesGateway.statusAddress.hostname = "localhost";
        additionalArguments = [
          "--entryPoints.web.forwardedHeaders.insecure=true"
          "--entryPoints.web.proxyProtocol.insecure=true"
          "--entryPoints.web.transport.respondingTimeouts.readTimeout=600s"
          "--entryPoints.web.transport.respondingTimeouts.writeTimeout=600s"
          "--entryPoints.web.transport.respondingTimeouts.idleTimeout=600s"
        ];
      };

      extraConfig = cfg: { nixidy.resourceImports = [ (toString crdImports.traefik) ]; };
    };
}
