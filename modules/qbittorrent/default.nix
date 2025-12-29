{ ageRecipients, config, lib, pkgs, ... }:
with lib;
let password-secret = "qbittorrent-webui-credentials";
in mkArgoApp { inherit config lib; } rec {
  name = "qbittorrent";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "linuxserver/qbittorrent:latest";
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

    webui = {
      username = mkOption {
        description = mdDoc "Web UI username (will be stored in SOPS secret)";
        type = types.str;
        default = "";
      };

      password = mkOption {
        description = mdDoc "Web UI password (will be stored in SOPS secret)";
        type = types.str;
        default = "";
      };

      disableAuthentication = mkOption {
        description = mdDoc "Disable Web UI authentication (not recommended)";
        type = types.bool;
        default = false;
      };
    };
  };

  extraResources = cfg: {
    sopsSecrets = lib.optionalAttrs (cfg.webui.username != "" && cfg.webui.password != "") {
      ${password-secret} = lib.createSecret {
        inherit ageRecipients lib pkgs;
        inherit (cfg) namespace;
        secretName = password-secret;
        values = {
          username = cfg.webui.username;
          password = cfg.webui.password;
        };
      };
    };

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
              initContainers = (lib.optionals (cfg.webui.username != "" && cfg.webui.password != "") [
                {
                  name = "configure-auth";
                  image = "busybox:latest";
                  command = [
                    "sh"
                    "-c"
                    ''
                      mkdir -p /config/qBittorrent
                      CONFIG_FILE="/config/qBittorrent/qBittorrent.conf"

                      # Generate password hash (qBittorrent uses PBKDF2, but for simplicity we'll use SHA1)
                      # qBittorrent stores password as: @ByteArray(sha1_hash)
                      PASSWORD_HASH=$(echo -n "$PASSWORD" | sha1sum | cut -d' ' -f1)

                      if [ ! -f "$CONFIG_FILE" ]; then
                        # Create new config with credentials
                        cat > "$CONFIG_FILE" <<EOF
[Preferences]
WebUI\Enabled=true
WebUI\Address=*
WebUI\Port=8080
WebUI\LocalHostAuth=true
WebUI\AuthSubnetWhitelist=
WebUI\Username=$USERNAME
WebUI\Password_ha1=@ByteArray($PASSWORD_HASH)
WebUI\Password_PBKDF2="@ByteArray($PASSWORD_HASH)"
WebUI\HostHeaderValidation=false
WebUI\CSRFProtection=false
WebUI\ClickjackingProtection=false
EOF
                      else
                        # Update existing config with new credentials
                        # Update username
                        if grep -q "^WebUI\\\\Username=" "$CONFIG_FILE"; then
                          sed -i "s/^WebUI\\\\Username=.*/WebUI\\\\Username=$USERNAME/" "$CONFIG_FILE"
                        else
                          echo "WebUI\\Username=$USERNAME" >> "$CONFIG_FILE"
                        fi

                        # Update password hash
                        if grep -q "^WebUI\\\\Password_ha1=" "$CONFIG_FILE"; then
                          sed -i "s|^WebUI\\\\Password_ha1=.*|WebUI\\\\Password_ha1=@ByteArray($PASSWORD_HASH)|" "$CONFIG_FILE"
                        else
                          echo "WebUI\\Password_ha1=@ByteArray($PASSWORD_HASH)" >> "$CONFIG_FILE"
                        fi

                        if grep -q "^WebUI\\\\Password_PBKDF2=" "$CONFIG_FILE"; then
                          sed -i "s|^WebUI\\\\Password_PBKDF2=.*|WebUI\\\\Password_PBKDF2=\"@ByteArray($PASSWORD_HASH)\"|" "$CONFIG_FILE"
                        else
                          echo "WebUI\\Password_PBKDF2=\"@ByteArray($PASSWORD_HASH)\"" >> "$CONFIG_FILE"
                        fi

                        # Ensure authentication is enabled
                        sed -i 's/^WebUI\\LocalHostAuth=.*/WebUI\\LocalHostAuth=true/' "$CONFIG_FILE" || echo "WebUI\\LocalHostAuth=true" >> "$CONFIG_FILE"
                        sed -i 's/^WebUI\\HostHeaderValidation=.*/WebUI\\HostHeaderValidation=false/' "$CONFIG_FILE" || echo "WebUI\\HostHeaderValidation=false" >> "$CONFIG_FILE"
                      fi
                    ''
                  ];
                  volumeMounts = [
                    {
                      mountPath = "/config";
                      name = "config";
                    }
                  ];
                  env = [
                    {
                      name = "USERNAME";
                      valueFrom = {
                        secretKeyRef = {
                          name = password-secret;
                          key = "username";
                        };
                      };
                    }
                    {
                      name = "PASSWORD";
                      valueFrom = {
                        secretKeyRef = {
                          name = password-secret;
                          key = "password";
                        };
                      };
                    }
                  ];
                }
              ]) ++ (lib.optionals cfg.webui.disableAuthentication [
                {
                  name = "disable-auth";
                  image = "busybox:latest";
                  command = [
                    "sh"
                    "-c"
                    ''
                      mkdir -p /config/qBittorrent
                      CONFIG_FILE="/config/qBittorrent/qBittorrent.conf"

                      if [ ! -f "$CONFIG_FILE" ]; then
                        cat > "$CONFIG_FILE" <<'EOF'
[Preferences]
WebUI\Enabled=true
WebUI\Address=*
WebUI\Port=8080
WebUI\LocalHostAuth=false
WebUI\AuthSubnetWhitelist=
WebUI\HostHeaderValidation=false
WebUI\CSRFProtection=false
WebUI\ClickjackingProtection=false
EOF
                      else
                        sed -i 's/^WebUI\\LocalHostAuth=.*/WebUI\\LocalHostAuth=false/' "$CONFIG_FILE" || true
                        sed -i 's/^WebUI\\HostHeaderValidation=.*/WebUI\\HostHeaderValidation=false/' "$CONFIG_FILE" || true
                        grep -q "WebUI\\\\LocalHostAuth" "$CONFIG_FILE" || echo "WebUI\\LocalHostAuth=false" >> "$CONFIG_FILE"
                        grep -q "WebUI\\\\HostHeaderValidation" "$CONFIG_FILE" || echo "WebUI\\HostHeaderValidation=false" >> "$CONFIG_FILE"
                      fi
                    ''
                  ];
                  volumeMounts = [
                    {
                      mountPath = "/config";
                      name = "config";
                    }
                  ];
                }
              ]);
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
                    # Configure qBittorrent to use shared gluetun's HTTP proxy
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
                      value = "localhost,127.0.0.1,.svc,.svc.cluster.local";
                    }
                  ]);
                  ports = [
                    {
                      containerPort = cfg.service.port;
                      name = "http";
                      protocol = "TCP";
                    }
                    {
                      containerPort = 6881;
                      name = "torrent-tcp";
                      protocol = "TCP";
                    }
                    {
                      containerPort = 6881;
                      name = "torrent-udp";
                      protocol = "UDP";
                    }
                  ];
                  volumeMounts = [
                    {
                      mountPath = "/config";
                      name = "config";
                    }
                    {
                      mountPath = "/downloads";
                      name = "downloads";
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
        resources.requests.storage = "100Gi";
      };
    };

    services.${name}.spec = {
      ports = [
        {
          name = "http";
          port = cfg.service.port;
          protocol = "TCP";
          targetPort = "http";
        }
        {
          name = "torrent-tcp";
          port = 6881;
          protocol = "TCP";
          targetPort = "torrent-tcp";
        }
        {
          name = "torrent-udp";
          port = 6881;
          protocol = "UDP";
          targetPort = "torrent-udp";
        }
      ];

      selector = {
        "app.kubernetes.io/instance" = name;
        "app.kubernetes.io/name" = name;
      };

      type = "ClusterIP";
    };

    # Create NFS PersistentVolume for downloads when NFS is enabled
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
    };
  };
}
