{ config, ... }:
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

    # Values for widgets that need an API key/password. Reference them from a
    # service's `homepage.extraSettings.widget.*` (or `widgets`/`extraGroups`
    # here) as `{{HOMEPAGE_VAR_<KEY>}}` -- homepage substitutes the placeholder
    # from the container env at render time, so the ConfigMap/git stay
    # plaintext-free. See applications/homepage.nix for how this is wired.
    # immich.nix auto-populates its own `homepage.extraSettings.widget` once
    # `services.immich.adminApiKey` is set -- this just has to supply the
    # matching env var for the `{{HOMEPAGE_VAR_IMMICH_API_KEY}}` placeholder.
    widgetSecrets = {
      IMMICH_API_KEY = config.services.immich.adminApiKey;
    };
  };
}
