{ nixhelm, nixidy, system, ... }: {
  packages.generators.traefik = nixidy.packages.${system}.generators.fromCRD {
    name = "traefik";
    src = nixhelm.chartsDerivations.${system}.traefik.traefik;
    crds = [
      "crds/traefik.io_ingressroutes.yaml"
      "crds/traefik.io_ingressroutetcps.yaml"
      "crds/traefik.io_ingressrouteudps.yaml"
      "crds/traefik.io_traefikservices.yaml"
    ];
  };
}
