{ charts, config, lib, ... }:
let
  cfg = config.services.demo;

  # chartConfig = {
  #   repo = "https://charts.goauthentik.io/";
  #   chart = "authentik";
  #   version = "2024.10.4";
  #   chartHash = "sha256-wMEFXWJDI8pHqKN7jrQ4K8+s1c2kv6iN6QxiLPZ1Ytk=";
  # };

  defaultNamespace = "demo";
  # domain = "authentik.dev.kronkltd.net";

  labels = { "app.kubernetes.io/name" = "nginx"; };
  # defaultValues = { };

  # values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  # namespace = cfg.namespace;
in with lib; {
  options.services.demo = {
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
    # Define a deployment for running an nginx server
    deployments.nginx.spec = {
      selector.matchLabels = labels;
      template = {
        metadata.labels = labels;
        spec = {
          securityContext.fsGroup = 1000;
          containers.nginx = {
            image = "nginx:1.25.1";
            imagePullPolicy = "IfNotPresent";
            volumeMounts = {
              "/etc/nginx".name = "config";
              "/var/lib/html".name = "static";
            };
          };
          volumes = {
            config.configMap.name = "nginx-config";
            static.configMap.name = "nginx-static";
          };
        };
      };
    };

    # # Define config maps with config for nginx
    # configMaps = {
    #   nginx-config.data."nginx.conf" = ''
    #     user nginx nginx;
    #     error_log /dev/stdout info;
    #     pid /dev/null;
    #     events {}
    #     http {
    #       access_log /dev/stdout;
    #       server {
    #         listen 80;
    #         index index.html;
    #         location / {
    #           root /var/lib/html;
    #         }
    #       }
    #     }
    #   '';

    #   nginx-static.data."index.html" = ''
    #     <html><body><h1>Hello from NGINX</h1></body></html>
    #   '';
    # };

    # Define service for nginx
    services.nginx.spec = {
      selector = labels;
      ports.http.port = 80;
    };
  };
}
