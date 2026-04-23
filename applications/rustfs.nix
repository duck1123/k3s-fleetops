{ ... }:
{
  flake.nixidyApps.rustfs =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    with lib;
    let
      credentials-secret = "rustfs-credentials";
    in
    self.lib.mkArgoApp
      {
        inherit
          config
          lib
          self
          pkgs
          ;
      }
      {
        name = "rustfs";

        sopsSecrets =
          cfg:
          optionalAttrs (cfg.accessKey != "" && cfg.secretKey != "") {
            ${credentials-secret} = {
              RUSTFS_ACCESS_KEY = cfg.accessKey;
              RUSTFS_SECRET_KEY = cfg.secretKey;
            };
          };

        # https://artifacthub.io/packages/helm/rustfs/rustfs
        chart = lib.helm.downloadHelmChart {
          repo = "https://charts.rustfs.com/";
          chart = "rustfs";
          version = "0.0.90";
          chartHash = "sha256-QoBu6mNbuJeF8DZLTQfG+QhZP/mU2ZD/uq6TZbPbqpU=";
        };

        uses-ingress = true;

        extraOptions = {
          ingress.api-domain = mkOption {
            description = mdDoc "The ingress domain for the S3 API";
            type = types.str;
            default = "api-rustfs.local";
          };

          accessKey = mkOption {
            description = mdDoc "RustFS access key (S3 Access Key ID)";
            type = types.str;
            default = "";
          };

          secretKey = mkOption {
            description = mdDoc "RustFS secret key (S3 Secret Access Key)";
            type = types.str;
            default = "";
          };

          mode = mkOption {
            description = mdDoc "Deployment mode: standalone (single pod) or distributed";
            type = types.enum [
              "standalone"
              "distributed"
            ];
            default = "standalone";
          };

          nfs = {
            enable = mkOption {
              description = mdDoc "Use NFS for data volume instead of a StorageClass";
              type = types.bool;
              default = false;
            };

            server = mkOption {
              description = mdDoc "NFS server hostname/IP";
              type = types.str;
              default = "";
            };

            path = mkOption {
              description = mdDoc "NFS export path";
              type = types.str;
              default = "";
            };
          };
        };

        extraResources =
          cfg:
          lib.optionalAttrs cfg.nfs.enable {
            persistentVolumes."rustfs-data-nfs".spec = {
              capacity.storage = "1Ti";
              accessModes = [ "ReadWriteOnce" ];
              storageClassName = "";
              claimRef = {
                name = "rustfs-data";
                namespace = "rustfs";
              };
              mountOptions = [
                "nolock"
                "soft"
                "timeo=30"
              ];
              nfs = {
                server = cfg.nfs.server;
                path = cfg.nfs.path;
              };
              persistentVolumeReclaimPolicy = "Retain";
            };
          };

        defaultValues =
          cfg:
          {
            replicaCount = if cfg.mode == "standalone" then 1 else 4;
            mode = {
              standalone.enabled = cfg.mode == "standalone";
              distributed.enabled = cfg.mode == "distributed";
            };

            secret =
              if cfg.accessKey != "" && cfg.secretKey != "" then
                { existingSecret = credentials-secret; }
              else
                {
                  rustfs = {
                    access_key = "rustfsadmin";
                    secret_key = "rustfsadmin";
                  };
                };

            storageclass.name = if cfg.nfs.enable then "" else cfg.storageClassName;

            ingress = with cfg.ingress; {
              enabled = true;
              className = ingressClassName;
              customAnnotations = {
                "cert-manager.io/cluster-issuer" = clusterIssuer;
              };
              hosts = [
                {
                  host = domain;
                  paths = [
                    {
                      path = "/";
                      pathType = "Prefix";
                    }
                  ];
                }
              ];
              tls = {
                enabled = tls.enable;
                certManager.enabled = false;
                existingSecret.enabled = false;
              };
            };
          }
          // optionalAttrs (cfg.hostAffinity != null) {
            nodeSelector."kubernetes.io/hostname" = cfg.hostAffinity;
          };
      };
}
