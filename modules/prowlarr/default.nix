{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "prowlarr";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "linuxserver/prowlarr:latest";
    };

    service.port = mkOption {
      description = mdDoc "The service port";
      type = types.int;
      default = 9696;
    };

    storageClassName = mkOption {
      description = mdDoc "The storage class";
      type = types.str;
      default = "longhorn";
    };

    vpn = {
      enable = mkOption {
        description = mdDoc "Enable VPN routing through shared gluetun service";
        type = types.bool;
        default = true;
      };

      sharedGluetunService = mkOption {
        description = mdDoc "Service name for shared gluetun (e.g., gluetun.gluetun)";
        type = types.str;
        default = "gluetun.gluetun";
      };
    };

    tz = mkOption {
      description = mdDoc "The timezone";
      type = types.str;
      default = "Etc/UTC";
    };

    pgid = mkOption {
      description = mdDoc "The group ID";
      type = types.int;
      default = 1000;
    };

    puid = mkOption {
      description = mdDoc "The user ID";
      type = types.int;
      default = 1000;
    };

    database = {
      enable = mkOption {
        description = mdDoc "Enable PostgreSQL database";
        type = types.bool;
        default = false;
      };

      host = mkOption {
        description = mdDoc "PostgreSQL database host";
        type = types.str;
        default = "postgresql.postgresql";
      };

      port = mkOption {
        description = mdDoc "PostgreSQL database port";
        type = types.int;
        default = 5432;
      };

      name = mkOption {
        description = mdDoc "PostgreSQL database name";
        type = types.str;
        default = "prowlarr";
      };

      username = mkOption {
        description = mdDoc "PostgreSQL database username";
        type = types.str;
        default = "prowlarr";
      };

      password = mkOption {
        description = mdDoc "PostgreSQL database password";
        type = types.str;
        default = "";
      };
    };
  };

  extraResources = cfg: {
    deployments = {
      ${name} = {
        metadata.labels = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = name;
          "app.kubernetes.io/version" = "latest";
        };

        spec = {
          selector.matchLabels = {
            "app.kubernetes.io/instance" = name;
            "app.kubernetes.io/name" = name;
          };

          template = {
            metadata.labels = {
              "app.kubernetes.io/instance" = name;
              "app.kubernetes.io/name" = name;
            };

            spec = {
              automountServiceAccountToken = true;
              serviceAccountName = "default";
              initContainers = lib.optionals (cfg.database.enable) [
                {
                  name = "configure-database";
                  image = "busybox:latest";
                  imagePullPolicy = "IfNotPresent";
                  command = [
                    "sh"
                    "-c"
                    ''
                      CONFIG_FILE="/config/config.xml"

                      # Wait for config file to exist (created on first run)
                      if [ ! -f "$CONFIG_FILE" ]; then
                        echo "Config file does not exist yet, will be created on first run"
                        exit 0
                      fi

                      # Create connection string
                      CONNECTION_STRING="Host=${cfg.database.host};Port=${toString cfg.database.port};Database=${cfg.database.name};Username=${cfg.database.username};Password=${cfg.database.password}"

                      # Use sed to update or add ConnectionString in config.xml
                      if grep -q "<ConnectionString>" "$CONFIG_FILE"; then
                        # Update existing ConnectionString
                        sed -i "s|<ConnectionString>.*</ConnectionString>|<ConnectionString>$CONNECTION_STRING</ConnectionString>|g" "$CONFIG_FILE"
                        echo "Updated existing ConnectionString"
                      else
                        # Add ConnectionString after <Config> tag
                        if grep -q "<Config>" "$CONFIG_FILE"; then
                          sed -i "/<Config>/a\  <ConnectionString>$CONNECTION_STRING</ConnectionString>" "$CONFIG_FILE"
                          echo "Added ConnectionString to config.xml"
                        else
                          echo "Warning: Could not find <Config> tag in config.xml"
                        fi
                      fi

                      echo "Database configuration complete"
                    ''
                  ];
                  volumeMounts = [{
                    mountPath = "/config";
                    name = "config";
                  }];
                }
              ];
              containers = [
                {
                  inherit name;
                  image = cfg.image;
                  imagePullPolicy = "IfNotPresent";
                  env = [
                    {
                      name = "PGID";
                      value = "${toString cfg.pgid}";
                    }
                    {
                      name = "PUID";
                      value = "${toString cfg.puid}";
                    }
                    {
                      name = "TZ";
                      value = cfg.tz;
                    }
                  ] ++ (lib.optionalAttrs cfg.vpn.enable [
                    # Configure Prowlarr to use shared gluetun's HTTP proxy
                    {
                      name = "HTTP_PROXY";
                      value = "http://${cfg.vpn.sharedGluetunService}:8888";
                    }
                    {
                      name = "HTTPS_PROXY";
                      value = "http://${cfg.vpn.sharedGluetunService}:8888";
                    }
                    {
                      name = "NO_PROXY";
                      value = "localhost,127.0.0.1,.svc,.svc.cluster.local,sabnzbd.sabnzbd,sabnzbd.sabnzbd.svc.cluster.local";
                    }
                  ]);
                  ports = [{
                    containerPort = cfg.service.port;
                    name = "http";
                    protocol = "TCP";
                  }];
                  readinessProbe = {
                    httpGet = {
                      path = "/";
                      port = cfg.service.port;
                    };
                    initialDelaySeconds = 10;
                    periodSeconds = 10;
                    timeoutSeconds = 5;
                    successThreshold = 1;
                    failureThreshold = 3;
                  };
                  livenessProbe = {
                    httpGet = {
                      path = "/";
                      port = cfg.service.port;
                    };
                    initialDelaySeconds = 30;
                    periodSeconds = 30;
                    timeoutSeconds = 5;
                    successThreshold = 1;
                    failureThreshold = 3;
                  };
                  volumeMounts = [
                    {
                      mountPath = "/config";
                      name = "config";
                    }
                  ];
                }
              ];
              volumes = [
                {
                  name = "config";
                  persistentVolumeClaim.claimName = "${name}-${name}-config";
                }
              ];
            };
          };
        };
      };
    };

    ingresses.${name}.spec = with cfg.ingress; {
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

    persistentVolumeClaims = {
      "${name}-${name}-config".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
      };
    };

    services.${name}.spec = {
      ports = [{
        name = "http";
        port = cfg.service.port;
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

