{ ... }:
{
  services.homepage = {
    enable = true;

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    monitoring.autokuma.enable = true;
    # Would otherwise list itself (uses-ingress defaults homepage.enable to true).
    homepage.enable = false;

    settings = {
      title = "Homelab";
      theme = "dark";
    };
  };
}
