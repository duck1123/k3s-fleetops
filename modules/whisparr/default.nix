{ ageRecipients, config, lib, pkgs, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "whisparr";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "ghcr.io/hotio/whisparr:latest";
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
        description = mdDoc "Enable VPN routing through Mullvad";
        type = types.bool;
        default = true;
      };

      mullvadAccountNumber = mkOption {
        description = mdDoc "Mullvad account number";
        type = types.str;
        default = "";
      };

      serverLocation = mkOption {
        description = mdDoc "Mullvad server location (e.g., us-was, se-sto)";
        type = types.str;
        default = "";
      };

      serverCountry = mkOption {
        description = mdDoc "Mullvad server country (e.g., USA, Sweden)";
        type = types.nullOr types.str;
        default = null;
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
              # Share process namespace with gluetun when VPN is enabled
              # This allows containers to communicate via localhost
              shareProcessNamespace = cfg.vpn.enable;
              containers = lib.flatten [
                # Gluetun VPN container (only if VPN is enabled)
                (lib.optional cfg.vpn.enable {
                  name = "gluetun";
                  image = "qmcgaw/gluetun:latest";
                  imagePullPolicy = "IfNotPresent";
                  securityContext = {
                    capabilities.add = [ "NET_ADMIN" "MKNOD" ];
                    privileged = false;
                  };
                  env = [
                    {
                      name = "VPN_SERVICE_PROVIDER";
                      value = "mullvad";
                    }
                    {
                      name = "VPN_TYPE";
                      value = "openvpn";
                    }
                    {
                      name = "MULLVAD_ACCOUNT_NUMBER";
                      value = cfg.vpn.mullvadAccountNumber;
                    }
                    {
                      name = "SERVER_COUNTRIES";
                      value = if cfg.vpn.serverCountry != null then cfg.vpn.serverCountry else "";
                    }
                    {
                      name = "SERVER_CITIES";
                      value = cfg.vpn.serverLocation;
                    }
                    {
                      name = "FIREWALL_VPN_INPUT_PORTS";
                      value = "${toString cfg.service.port}";
                    }
                    {
                      name = "FIREWALL";
                      value = "on";
                    }
                    {
                      name = "FIREWALL_DEBUG";
                      value = "off";
                    }
                    {
                      name = "UPDATER_PERIOD";
                      value = "24h";
                    }
                    {
                      name = "TZ";
                      value = cfg.tz;
                    }
                    {
                      name = "HTTP_CONTROL_SERVER_LOG";
                      value = "on";
                    }
                  ];
                  ports = [
                    {
                      containerPort = cfg.service.port;
                      name = "http";
                      protocol = "TCP";
                    }
                    {
                      containerPort = 8888;
                      name = "http-proxy";
                      protocol = "TCP";
                    }
                    {
                      containerPort = 1080;
                      name = "socks-proxy";
                      protocol = "TCP";
                    }
                  ];
                  volumeMounts = [
                    {
                      mountPath = "/gluetun";
                      name = "gluetun";
                    }
                  ];
                })
                # Whisparr container
                [{
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
                    # Configure Whisparr to use gluetun's HTTP proxy
                    {
                      name = "HTTP_PROXY";
                      value = "http://127.0.0.1:8888";
                    }
                    {
                      name = "HTTPS_PROXY";
                      value = "http://127.0.0.1:8888";
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
                      mountPath = "/tv";
                      name = "tv";
                    }
                  ];
                }]
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
                  name = "tv";
                  persistentVolumeClaim.claimName = "${name}-${name}-tv";
                }
                (lib.optionalAttrs cfg.vpn.enable {
                  name = "gluetun";
                  persistentVolumeClaim.claimName = "${name}-${name}-gluetun";
                })
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
      "${name}-${name}-tv".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-tv-nfs";
      } else {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "100Gi";
      };
    } // (lib.optionalAttrs cfg.vpn.enable {
      "${name}-${name}-gluetun".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "1Gi";
      };
    });

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

    # Create NFS PersistentVolumes for downloads and tv when NFS is enabled
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
      "${name}-${name}-tv-nfs" = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = "${name}-${name}-tv-nfs";
        };
        spec = {
          capacity = {
            storage = "1Ti";
          };
          accessModes = [ "ReadWriteMany" ];
          nfs = {
            server = cfg.nfs.server;
            path = "${cfg.nfs.path}/TV";
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
    };
  };
}

