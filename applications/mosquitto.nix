{ ... }:
{
  flake.nixidyApps.mosquitto =
    {
      config,
      lib,
      self,
      ...
    }:
    with lib;
    let
      name = "mosquitto";
      configMapName = "${name}-config";
    in
    self.lib.mkArgoApp { inherit config lib self; } rec {
      inherit name;
      uses-ingress = false;

      extraOptions = {
        image = mkOption {
          description = mdDoc "Eclipse Mosquitto image (e.g. eclipse-mosquitto:2)";
          type = types.str;
          default = "eclipse-mosquitto:2";
        };

        mqttPort = mkOption {
          description = mdDoc "MQTT TCP port (container and Service)";
          type = types.int;
          default = 1883;
        };

        storageClassName = mkOption {
          description = mdDoc "Storage class for broker persistence (`/mosquitto/data`)";
          type = types.str;
          default = "longhorn";
        };

        dataVolumeSize = mkOption {
          description = mdDoc "PVC size for Mosquitto data";
          type = types.str;
          default = "5Gi";
        };

        serviceType = mkOption {
          description = mdDoc "Service type: ClusterIP (in-cluster only) or LoadBalancer (MetalLB VIP for LAN MQTT clients)";
          type = types.enum [
            "ClusterIP"
            "LoadBalancer"
          ];
          default = "LoadBalancer";
        };

        loadBalancerIP = mkOption {
          description = mdDoc "Optional fixed MetalLB IP when `serviceType` is LoadBalancer";
          type = types.nullOr types.str;
          default = null;
        };

        replicas = mkOption {
          description = mdDoc "Replica count (keep 1 with ReadWriteOnce PVC)";
          type = types.int;
          default = 1;
        };

        useProbes = mkOption {
          description = mdDoc "TCP probes on the MQTT port";
          type = types.bool;
          default = true;
        };

        extraMosquittoConf = mkOption {
          description = mdDoc "Additional lines appended to `mosquitto.conf` (after listener/persistence defaults)";
          type = types.lines;
          default = "";
        };
      };

      extraResources =
        svc:
        let
          baseConf = ''
            listener ${toString svc.mqttPort}
            allow_anonymous true
            persistence true
            persistence_location /mosquitto/data/
            log_dest stdout
          '';
          mosquittoConf =
            if svc.extraMosquittoConf != "" then baseConf + "\n" + svc.extraMosquittoConf else baseConf;
        in
        {
          configMaps.${configMapName}.data."mosquitto.conf" = mosquittoConf;

          deployments.${name} = {
            metadata.labels = {
              "app.kubernetes.io/instance" = name;
              "app.kubernetes.io/name" = name;
              "app.kubernetes.io/version" = "2";
            };

            spec = {
              replicas = svc.replicas;
              strategy.type = "Recreate";

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

                  securityContext.fsGroup = 1883;

                  containers = [
                    {
                      inherit name;
                      image = svc.image;
                      imagePullPolicy = "IfNotPresent";

                      ports = [
                        {
                          containerPort = svc.mqttPort;
                          name = "mqtt";
                          protocol = "TCP";
                        }
                      ];

                      volumeMounts = [
                        {
                          name = "config";
                          mountPath = "/mosquitto/config";
                          readOnly = true;
                        }
                        {
                          name = "data";
                          mountPath = "/mosquitto/data";
                        }
                      ];

                      readinessProbe = mkIf svc.useProbes {
                        tcpSocket = {
                          port = "mqtt";
                        };
                        initialDelaySeconds = 5;
                        periodSeconds = 10;
                        timeoutSeconds = 5;
                        successThreshold = 1;
                        failureThreshold = 3;
                      };

                      livenessProbe = mkIf svc.useProbes {
                        tcpSocket = {
                          port = "mqtt";
                        };
                        initialDelaySeconds = 30;
                        periodSeconds = 30;
                        timeoutSeconds = 5;
                        successThreshold = 1;
                        failureThreshold = 3;
                      };

                      resources = {
                        requests = {
                          cpu = "50m";
                          memory = "64Mi";
                        };
                        limits = {
                          cpu = "1";
                          memory = "512Mi";
                        };
                      };
                    }
                  ];

                  volumes = [
                    {
                      name = "config";
                      configMap = {
                        name = configMapName;
                        defaultMode = 420; # 0644
                      };
                    }
                    {
                      name = "data";
                      persistentVolumeClaim.claimName = "${name}-${name}-data";
                    }
                  ];
                };
              };
            };
          };

          services.${name}.spec = {
            ports = [
              {
                name = "mqtt";
                port = svc.mqttPort;
                protocol = "TCP";
                targetPort = "mqtt";
              }
            ];

            selector = {
              "app.kubernetes.io/instance" = name;
              "app.kubernetes.io/name" = name;
            };

            type = svc.serviceType;
          }
          // optionalAttrs (svc.loadBalancerIP != null) {
            loadBalancerIP = svc.loadBalancerIP;
          };

          persistentVolumeClaims."${name}-${name}-data".spec = {
            inherit (svc) storageClassName;
            accessModes = [ "ReadWriteOnce" ];
            resources.requests.storage = svc.dataVolumeSize;
          };
        };
    };
}
