{ config, lib, ... }:
with lib;
mkArgoApp {
  inherit config lib;
  # Application will be in argocd namespace (default)
  # Resources will be deployed to kube-system (set via namespace parameter)
  namespace = "kube-system";
} rec {
  name = "amd-gpu-device-plugin";
  namespace = "kube-system";

  extraOptions = {
    image = mkOption {
      description = mdDoc "The AMD GPU device plugin docker image";
      type = types.str;
      default = "rocm/k8s-device-plugin:latest";
    };
  };

  extraResources = cfg: {
    daemonSets = {
      "amdgpu-device-plugin-daemonset" = {
        metadata = {
          name = "amdgpu-device-plugin-daemonset";
          namespace = cfg.namespace;
          labels = {
            "app.kubernetes.io/name" = name;
            "app.kubernetes.io/component" = "device-plugin";
          };
        };

        spec = {
          selector.matchLabels = {
            name = "amdgpu-dp-ds";
          };

          template = {
            metadata.labels = {
              name = "amdgpu-dp-ds";
            };

            spec = {
              restartPolicy = "Always";
              priorityClassName = "system-node-critical";

              nodeSelector = {
                "kubernetes.io/arch" = "amd64";
              };

              tolerations = [
                {
                  key = "CriticalAddonsOnly";
                  operator = "Exists";
                }
              ];

              containers = [{
                name = "amdgpu-dp-cntr";
                image = cfg.image;
                imagePullPolicy = "IfNotPresent";

                securityContext = {
                  privileged = true;
                  capabilities = {
                    drop = [ "ALL" ];
                  };
                };

                volumeMounts = [
                  {
                    name = "dp";
                    mountPath = "/var/lib/kubelet/device-plugins";
                  }
                  {
                    name = "sys";
                    mountPath = "/sys";
                  }
                ];
              }];

              volumes = [
                {
                  name = "dp";
                  hostPath = {
                    path = "/var/lib/kubelet/device-plugins";
                    type = "DirectoryOrCreate";
                  };
                }
                {
                  name = "sys";
                  hostPath = {
                    path = "/sys";
                    type = "Directory";
                  };
                }
              ];
            };
          };
        };
      };
    };
  };
}

