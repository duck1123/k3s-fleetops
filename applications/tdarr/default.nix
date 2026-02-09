{
  config,
  lib,
  pkgs,
  self,
  ...
}:
with lib;
self.lib.mkArgoApp { inherit config lib; } rec {
  name = "tdarr";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "ghcr.io/haveagitgat/tdarr:latest";
    };

    service.port = mkOption {
      description = mdDoc "The web UI service port";
      type = types.int;
      default = 8265;
    };

    server.port = mkOption {
      description = mdDoc "The Tdarr server port (for node communication)";
      type = types.int;
      default = 8266;
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
        description = mdDoc "Enable NFS for media and temp volumes";
        type = types.bool;
        default = false;
      };

      server = mkOption {
        description = mdDoc "NFS server hostname/IP";
        type = types.str;
        default = "nasnix";
      };

      path = mkOption {
        description = mdDoc "NFS server base path";
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

    replicas = mkOption {
      description = mdDoc "Number of replicas";
      type = types.int;
      default = 1;
    };

    useProbes = mkOption {
      description = mdDoc "Enable readiness and liveness probes";
      type = types.bool;
      default = true;
    };

    internalNode = mkOption {
      description = mdDoc "Enable internal Tdarr node in the server container";
      type = types.bool;
      default = true;
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
          replicas = cfg.replicas;
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

              containers = [
                {
                  inherit name;
                  image = cfg.image;
                  imagePullPolicy = "IfNotPresent";
                  env = [
                    { name = "PGID"; value = "${toString cfg.pgid}"; }
                    { name = "PUID"; value = "${toString cfg.puid}"; }
                    { name = "TZ"; value = cfg.tz; }
                    { name = "serverIP"; value = "0.0.0.0"; }
                    { name = "serverPort"; value = toString cfg.server.port; }
                    { name = "webUIPort"; value = toString cfg.service.port; }
                    { name = "internalNode"; value = if cfg.internalNode then "true" else "false"; }
                    { name = "inContainer"; value = "true"; }
                    { name = "auth"; value = "false"; }
                  ]
                  ++ (lib.optionals cfg.vpn.enable [
                    { name = "HTTP_PROXY"; value = "http://${cfg.vpn.sharedGluetunService}:8888"; }
                    { name = "HTTPS_PROXY"; value = "http://${cfg.vpn.sharedGluetunService}:8888"; }
                    { name = "NO_PROXY"; value = "localhost,127.0.0.1,.svc,.svc.cluster.local"; }
                  ]);
                  ports = [
                    { containerPort = cfg.service.port; name = "http"; protocol = "TCP"; }
                    { containerPort = cfg.server.port; name = "server"; protocol = "TCP"; }
                  ];
                  readinessProbe = lib.mkIf cfg.useProbes {
                    httpGet = { path = "/"; port = cfg.service.port; };
                    initialDelaySeconds = 60;
                    periodSeconds = 10;
                    timeoutSeconds = 5;
                    successThreshold = 1;
                    failureThreshold = 3;
                  };
                  livenessProbe = lib.mkIf cfg.useProbes {
                    httpGet = { path = "/"; port = cfg.service.port; };
                    initialDelaySeconds = 90;
                    periodSeconds = 30;
                    timeoutSeconds = 5;
                    successThreshold = 1;
                    failureThreshold = 3;
                  };
                  volumeMounts = [
                    { mountPath = "/app"; name = "config"; }
                    { mountPath = "/temp"; name = "temp"; }
                    { mountPath = "/media"; name = "media"; }
                  ];
                }
              ];

              nodeSelector."kubernetes.io/hostname" = cfg.hostAffinity;
              serviceAccountName = "default";
              initContainers = lib.optionalAttrs cfg.vpn.enable (
                self.lib.waitForGluetun { inherit lib; } cfg.vpn.sharedGluetunService
              );

              volumes = [
                { name = "config"; persistentVolumeClaim.claimName = "${name}-${name}-config"; }
                { name = "temp"; persistentVolumeClaim.claimName = "${name}-${name}-temp"; }
                { name = "media"; persistentVolumeClaim.claimName = "${name}-${name}-media"; }
              ];
            };
          };
        };
      };
    };

    ingresses.${name}.spec = with cfg.ingress; {
      inherit ingressClassName;

      rules = [
        {
          host = domain;
          http.paths = [
            {
              backend.service = { inherit name; port.name = "http"; };
              path = "/";
              pathType = "ImplementationSpecific";
            }
          ];
        }
      ];

      tls = [ { hosts = [ domain ]; } ];
    };

    persistentVolumeClaims = {
      "${name}-${name}-config".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "10Gi";
      };
      "${name}-${name}-temp".spec =
        if cfg.nfs.enable then
          {
            accessModes = [ "ReadWriteMany" ];
            resources.requests.storage = "1Gi";
            storageClassName = "";
            volumeName = "${name}-${name}-temp-nfs";
          }
        else
          {
            inherit (cfg) storageClassName;
            accessModes = [ "ReadWriteOnce" ];
            resources.requests.storage = "50Gi";
          };
      "${name}-${name}-media".spec =
        if cfg.nfs.enable then
          {
            accessModes = [ "ReadWriteMany" ];
            resources.requests.storage = "1Gi";
            storageClassName = "";
            volumeName = "${name}-${name}-media-nfs";
          }
        else
          {
            inherit (cfg) storageClassName;
            accessModes = [ "ReadWriteOnce" ];
            resources.requests.storage = "100Gi";
          };
    };

    services.${name}.spec = {
      ports = [
        { name = "http"; port = cfg.service.port; protocol = "TCP"; targetPort = "http"; }
        { name = "server"; port = cfg.server.port; protocol = "TCP"; targetPort = "server"; }
      ];
      selector = {
        "app.kubernetes.io/instance" = name;
        "app.kubernetes.io/name" = name;
      };
      type = "ClusterIP";
    };

    # Create NFS PersistentVolumes for temp and media when NFS is enabled
    persistentVolumes = lib.optionalAttrs (cfg.nfs.enable) {
      "${name}-${name}-temp-nfs" = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = { name = "${name}-${name}-temp-nfs"; };
        spec = {
          capacity = { storage = "1Ti"; };
          accessModes = [ "ReadWriteMany" ];
          mountOptions = [ "nolock" "soft" "timeo=30" ];
          nfs = {
            server = cfg.nfs.server;
            path = "${cfg.nfs.path}/tdarr-temp";
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
      "${name}-${name}-media-nfs" = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = { name = "${name}-${name}-media-nfs"; };
        spec = {
          capacity = { storage = "1Ti"; };
          accessModes = [ "ReadWriteMany" ];
          mountOptions = [ "nolock" "soft" "timeo=30" ];
          nfs = {
            server = cfg.nfs.server;
            path = cfg.nfs.path;
          };
          persistentVolumeReclaimPolicy = "Retain";
        };
      };
    };
  };
}
