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

    # Cluster nodes run glances (dotfiles' `features.glances`, port 61208) directly
    # on the host OS -- not a k8s app, so it can't be auto-discovered like
    # mkArgoApp services and is listed here by static LAN IP instead.
    extraGroups = {
      Nodes = {
        nixmini = {
          href = "http://192.168.0.25:61208";
          widget = {
            type = "glances";
            url = "http://192.168.0.25:61208";
            version = 4;
            metric = "cpu";
          };
        };

        nasnix = {
          href = "http://192.168.0.16:61208";
          widget = {
            type = "glances";
            url = "http://192.168.0.16:61208";
            version = 4;
            metric = "cpu";
          };
        };

        edgenix = {
          href = "http://192.168.0.22:61208";
          widget = {
            type = "glances";
            url = "http://192.168.0.22:61208";
            version = 4;
            metric = "cpu";
          };
        };

        inspernix = {
          href = "http://192.168.0.24:61208";
          widget = {
            type = "glances";
            url = "http://192.168.0.24:61208";
            version = 4;
            metric = "cpu";
          };
        };

        powerspecnix = {
          href = "http://192.168.0.29:61208";
          widget = {
            type = "glances";
            url = "http://192.168.0.29:61208";
            version = 4;
            metric = "cpu";
          };
        };
      };
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
