{ ageRecipients, config, lib, pkgs, ... }:
with lib;
let password-secret = "lidarr-database-password";
in mkArgoApp { inherit config lib; } rec {
  name = "lidarr";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "linuxserver/lidarr:latest";
    };

    service.port = mkOption {
      description = mdDoc "The service port";
      type = types.int;
      default = 8686;
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
        default = "lidarr";
      };

      username = mkOption {
        description = mdDoc "PostgreSQL database username";
        type = types.str;
        default = "lidarr";
      };

      password = mkOption {
        description = mdDoc "PostgreSQL database password";
        type = types.str;
        default = "";
      };
    };
  };

  extraResources = cfg: {
    sopsSecrets = lib.optionalAttrs (cfg.database.enable && cfg.database.password != "") {
      ${password-secret} = lib.createSecret {
        inherit ageRecipients lib pkgs;
        inherit (cfg) namespace;
        secretName = password-secret;
        values = {
          password = cfg.database.password;
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
              initContainers = lib.optionals (cfg.database.enable && cfg.database.password != "") [
                {
                  name = "setup-database-env";
                  image = "busybox:latest";
                  imagePullPolicy = "IfNotPresent";
                  command = [
                    "sh"
                    "-c"
                    ''
                      PASSWORD=$(cat /secrets/password)
                      CONNECTION_STRING="Host=${cfg.database.host};Port=${toString cfg.database.port};Database=${cfg.database.name};Username=${cfg.database.username};Password=$PASSWORD"
                      echo "$CONNECTION_STRING" > /shared/lidarr-connection-string
                    ''
                  ];
                  volumeMounts = [
                    {
                      mountPath = "/secrets";
                      name = password-secret;
                    }
                    {
                      mountPath = "/shared";
                      name = "shared-env";
                    }
                  ];
                }
              ];
              containers = [
                {
                  inherit name;
                  image = cfg.image;
                  imagePullPolicy = "IfNotPresent";
                  command = if (cfg.database.enable && cfg.database.password != "") then [
                    "sh"
                    "-c"
                    ''
                      if [ -f /shared/lidarr-connection-string ]; then
                        export LIDARR__CONNECTIONSTRING=$(cat /shared/lidarr-connection-string)
                      fi
                      exec /init
                    ''
                  ] else null;
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
                  ] ++ (lib.optionalAttrs cfg.database.enable [
                    {
                      name = "LIDARR__CONNECTIONTYPE";
                      value = "PostgreSQL";
                    }
                  ]) ++ (lib.optionalAttrs cfg.vpn.enable [
                    # Configure Lidarr to use shared gluetun's HTTP proxy
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
                    (lib.optionalAttrs (cfg.database.enable && cfg.database.password != "") {
                      mountPath = "/shared";
                      name = "shared-env";
                    })
                    {
                      mountPath = "/downloads";
                      name = "downloads";
                    }
                    {
                      mountPath = "/music";
                      name = "music";
                    }
                  ];
                }
              ];
              volumes = [
                {
                  name = "config";
                  persistentVolumeClaim.claimName = "${name}-${name}-config";
                }
                (lib.optionalAttrs (cfg.database.enable && cfg.database.password != "") {
                  name = password-secret;
                  secret.secretName = password-secret;
                })
                (lib.optionalAttrs (cfg.database.enable && cfg.database.password != "") {
                  name = "shared-env";
                  emptyDir = {};
                })
                {
                  name = "downloads";
                  persistentVolumeClaim.claimName = "${name}-${name}-downloads";
                }
                {
                  name = "music";
                  persistentVolumeClaim.claimName = "${name}-${name}-music";
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

    persistentVolumes = lib.optionalAttrs (cfg.nfs.enable) {
      "${name}-${name}-downloads-nfs" = {
        apiVersion = "v1";
        metadata.name = "${name}-${name}-downloads-nfs";
        spec = {
          accessModes = [ "ReadWriteMany" ];
          capacity.storage = "1Ti";
          nfs = {
            server = cfg.nfs.server;
            path = "${cfg.nfs.path}/Downloads";
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
      "${name}-${name}-music-nfs" = {
        apiVersion = "v1";
        metadata.name = "${name}-${name}-music-nfs";
        spec = {
          capacity = { storage = "1Ti"; };
          accessModes = [ "ReadWriteMany" ];
          nfs = {
            server = cfg.nfs.server;
            path = "${cfg.nfs.path}/Music";
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
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
      "${name}-${name}-music".spec = if cfg.nfs.enable then {
        accessModes = [ "ReadWriteMany" ];
        resources.requests.storage = "1Gi";
        storageClassName = "";
        volumeName = "${name}-${name}-music-nfs";
      } else {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "100Gi";
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
