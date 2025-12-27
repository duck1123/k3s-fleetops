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
      description = mdDoc "Comma-separated list of hostnames allowed to access SABnzbd (empty to disable hostname verification). The service name and FQDN are automatically added.";
      type = types.str;
      default = "";
    };

    disableHostnameVerification = mkOption {
      description = mdDoc "Disable hostname verification entirely (not recommended for production)";
      type = types.bool;
      default = false;
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
              initContainers = let
                hostnameList = if cfg.disableHostnameVerification then
                  "*"
                else
                  lib.concatStringsSep " " (
                    lib.filter (x: x != "") [
                      (lib.replaceStrings [","] [" "] cfg.hostWhitelist)
                      (if cfg.ingress.domain != "" then cfg.ingress.domain else "")
                      "${name}.${cfg.namespace}"
                      "${name}.${cfg.namespace}.svc.cluster.local"
                    ]
                  );
              in [{
                name = "set-hostname-whitelist";
                image = "busybox:latest";
                command = [
                  "sh"
                  "-c"
                  ''
                    CONFIG_FILE="/config/sabnzbd.ini"
                    SERVICE_NAME="${name}.${cfg.namespace}"
                    SERVICE_FQDN="${name}.${cfg.namespace}.svc.cluster.local"
                    ALL_HOSTNAMES="${hostnameList}"
                    # Convert commas to spaces and clean up duplicates (safe even for wildcard)
                    if [ "$ALL_HOSTNAMES" != "*" ]; then
                      ALL_HOSTNAMES=$(echo "$ALL_HOSTNAMES" | tr ',' ' ' | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//')
                    fi

                    # Wait for config volume to be available
                    while [ ! -d /config ]; do
                      sleep 1
                    done

                    # Create config file if it doesn't exist
                    if [ ! -f "$CONFIG_FILE" ]; then
                      touch "$CONFIG_FILE"
                    fi

                    # Ensure [misc] section exists
                    if ! grep -q "^\[misc\]" "$CONFIG_FILE"; then
                      echo "" >> "$CONFIG_FILE"
                      echo "[misc]" >> "$CONFIG_FILE"
                    fi

                    # Remove any existing host_whitelist and api_warnings entries
                    sed -i '/^host_whitelist/d' "$CONFIG_FILE"
                    sed -i '/^api_warnings/d' "$CONFIG_FILE"

                    # Always set host_whitelist - SABnzbd requires it and cannot be fully disabled
                    ${lib.optionalString cfg.disableHostnameVerification ''
                      # Also disable api_warnings to suppress warnings
                      if grep -q "^\[misc\]" "$CONFIG_FILE"; then
                        sed -i "/^\[misc\]/a api_warnings = 0" "$CONFIG_FILE"
                      else
                        echo "api_warnings = 0" >> "$CONFIG_FILE"
                      fi
                    ''}

                    # Add host_whitelist to [misc] section
                    if grep -q "^\[misc\]" "$CONFIG_FILE"; then
                      sed -i "/^\[misc\]/a host_whitelist = $ALL_HOSTNAMES" "$CONFIG_FILE"
                    else
                      echo "host_whitelist = $ALL_HOSTNAMES" >> "$CONFIG_FILE"
                    fi
                    echo "Hostname whitelist set to: $ALL_HOSTNAMES"
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

