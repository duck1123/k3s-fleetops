{ ... }:
{
  flake.nixidyApps.longhorn =
    {
      charts,
      config,
      lib,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp { inherit config lib; } {
      name = "longhorn";
      namespace = "longhorn-system";

      # https://artifacthub.io/packages/helm/longhorn/longhorn
      chart = charts.longhorn.longhorn;

      uses-ingress = true;

      extraOptions = {
        backupTarget = mkOption {
          description = mdDoc "NFS or S3 backup target URL (e.g. nfs://host:/path)";
          type = types.str;
          default = "";
        };
      };

      extraAppConfig = cfg: lib.optionalAttrs (cfg.backupTarget != "") {
        yamls = [
          ''
            apiVersion: longhorn.io/v1beta2
            kind: BackupTarget
            metadata:
              name: default
              namespace: longhorn-system
            spec:
              backupTargetURL: "${cfg.backupTarget}"
              credentialSecret: ""
              pollInterval: "5m0s"
          ''
        ];
      };

      defaultValues = cfg: {
        defaultSettings = {
          defaultReplicaCount = 1;
          replicaFileSyncHttpClientTimeout = 120;
        };

        ingress = with cfg.ingress; {
          inherit ingressClassName;
          enabled = true;
          host = domain;
          tls = tls.enable;
        };

        longhornUI.replicas = 1;

        persistence = {
          defaultClass = false;
          defaultClassReplicaCount = 1;
        };

        preUpgradeChecker.jobEnabled = false;

        # Ensure Longhorn runs on all nodes, including control-plane nodes
        longhornManager = {
          tolerations = [
            {
              key = "node-role.kubernetes.io/control-plane";
              operator = "Exists";
              effect = "NoSchedule";
            }
            {
              key = "node-role.kubernetes.io/master";
              operator = "Exists";
              effect = "NoSchedule";
            }
            {
              key = "CriticalAddonsOnly";
              operator = "Exists";
            }
          ];
        };

        # Ensure CSI plugin runs on all nodes
        csi = {
          attacherReplicas = 3;
          provisionerReplicas = 3;
          resizerReplicas = 3;
          snapshotterReplicas = 3;
          tolerations = [
            {
              key = "node-role.kubernetes.io/control-plane";
              operator = "Exists";
              effect = "NoSchedule";
            }
            {
              key = "node-role.kubernetes.io/master";
              operator = "Exists";
              effect = "NoSchedule";
            }
            {
              key = "CriticalAddonsOnly";
              operator = "Exists";
            }
          ];
        };
      };
    };
}
