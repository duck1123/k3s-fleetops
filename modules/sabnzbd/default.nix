{ ageRecipients, config, lib, pkgs, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "sabnzbd";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "linuxserver/sabnzbd:latest";
    };

    service.port = mkOption {
      description = mdDoc "The service port";
      type = types.int;
      default = 8080;
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

    nfs = {
      enable = mkOption {
        description = mdDoc "Enable NFS for downloads volume";
        type = types.bool;
        default = false;
      };

      server = mkOption {
        description = mdDoc "NFS server hostname/IP";
        type = types.str;
        default = "nasnix";
      };

      path = mkOption {
        description = mdDoc "NFS server path";
        type = types.str;
        default = "/mnt/media";
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

    hostWhitelist = mkOption {
      description = mdDoc "Comma-separated list of hostnames allowed to access SABnzbd (empty to disable hostname verification)";
      type = types.str;
      default = "";
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
              # Init container to set hostname whitelist in config
              initContainers = [{
                name = "set-hostname-whitelist";
                image = "busybox:latest";
                command = [
                  "sh"
                  "-c"
                  ''
                    CONFIG_FILE="/config/sabnzbd.ini"
                    SERVICE_NAME="${name}.${cfg.namespace}"
                    ${if cfg.hostWhitelist != "" then ''
                      HOSTNAME="${cfg.hostWhitelist},$SERVICE_NAME"
                    '' else if cfg.ingress.domain != "" then ''
                      HOSTNAME="${cfg.ingress.domain},$SERVICE_NAME"
                    '' else ''
                      HOSTNAME="$SERVICE_NAME"
                    ''}

                    # Wait for config volume to be available
                    while [ ! -d /config ]; do
                      sleep 1
                    done

                    # Create config file if it doesn't exist
                    if [ ! -f "$CONFIG_FILE" ]; then
                      touch "$CONFIG_FILE"
                    fi

                    # Update or add host_whitelist setting
                    if [ -n "$HOSTNAME" ]; then
                      if grep -q "^host_whitelist" "$CONFIG_FILE"; then
                        # Update existing setting, but preserve existing entries
                        EXISTING=$(grep "^host_whitelist" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
                        if echo "$EXISTING" | grep -q "$SERVICE_NAME"; then
                          # Service name already in list, just update
                          sed -i "s|^host_whitelist.*|host_whitelist = $HOSTNAME|" "$CONFIG_FILE"
                        else
                          # Add service name to existing list
                          sed -i "s|^host_whitelist.*|host_whitelist = $EXISTING,$SERVICE_NAME|" "$CONFIG_FILE"
                        fi
                      else
                        # Add new setting
                        echo "host_whitelist = $HOSTNAME" >> "$CONFIG_FILE"
                      fi
                    else
                      # Remove host_whitelist to disable verification
                      sed -i "/^host_whitelist/d" "$CONFIG_FILE"
                    fi
                  ''
                ];
                volumeMounts = [{
                  mountPath = "/config";
                  name = "config";
                }];
              }];
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
                    # Configure Sabnzbd to use shared gluetun's HTTP proxy
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
                      value = "localhost,127.0.0.1";
                    }
                  ]);
                  ports = [{
                    containerPort = cfg.service.port;
                    name = "http";
                    protocol = "TCP";
                  }];
                  volumeMounts = [
                    {
                      mountPath = "/config";
                      name = "config";
                    }
                    {
                      mountPath = "/downloads";
                      name = "downloads";
                    }
                    {
                      mountPath = "/incomplete-downloads";
                      name = "incomplete-downloads";
                    }
                  ];
                }
              ];
              volumes = [
                {
                  name = "config";
                  persistentVolumeClaim.claimName = "${name}-${name}-config";
                }
                {
                  name = "downloads";
                  persistentVolumeClaim.claimName = "${name}-${name}-downloads";
                }
                {
                  name = "incomplete-downloads";
                  persistentVolumeClaim.claimName = "${name}-${name}-incomplete-downloads";
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
      "${name}-${name}-downloads".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-downloads-nfs";
      } else {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "50Gi";
      };
      "${name}-${name}-incomplete-downloads".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-incomplete-downloads-nfs";
      } else {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "20Gi";
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

    # Create NFS PersistentVolumes for downloads when NFS is enabled
    persistentVolumes = lib.optionalAttrs (cfg.nfs.enable) {
      "${name}-${name}-downloads-nfs" = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "${name}-${name}-downloads-nfs";
        };
        spec = {
          capacity = {
            storage = "1Ti";
          };
          accessModes = [ "ReadWriteMany" ];
          nfs = {
            server = cfg.nfs.server;
            path = "${cfg.nfs.path}/Downloads";
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
      "${name}-${name}-incomplete-downloads-nfs" = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "${name}-${name}-incomplete-downloads-nfs";
        };
        spec = {
          capacity = {
            storage = "1Ti";
          };
          accessModes = [ "ReadWriteMany" ];
          nfs = {
            server = cfg.nfs.server;
            path = "${cfg.nfs.path}/Downloads/incomplete";
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
    };

  };
}

