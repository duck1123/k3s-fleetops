{ ... }:
{
  flake.nixidyApps.kite =
    {
      config,
      lib,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp { inherit config lib; } {
      name = "kite";

      # https://github.com/kite-org/kite (formerly zxh326/kite)
      chart = helm.downloadHelmChart {
        repo = "https://zxh326.github.io/kite";
        chart = "kite";
        version = "0.14.1";
        chartHash = "sha256-esxcmhoBhhxjByM3KftrYFlD8h2a0fwT933ZRz8DuyE=";
      };

      uses-ingress = true;

      extraOptions = {
        encryptKey = mkOption {
          description = mdDoc "This is the key used for encrypting sensitive data";
          type = types.str;
          default = "kite-default-encryption-key-change-in-production";
        };

        jwtSecret = mkOption {
          description = mdDoc "This is the key used for signing JWT tokens";
          type = types.str;
          default = "kite-default-jwt-secret-key-change-in-production";
        };
      };

      defaultValues =
        cfg: with cfg; {
          inherit encryptKey jwtSecret;
          deploymentStrategy.type = "Recreate";
          db.sqlite.persistence.pvc = {
            enabled = true;
            accessModes = [ "ReadWriteOnce" ];
            size = "1Gi";
            storageClass = cfg.storageClassName;
          };
          host = ingress.domain;
          ingress = with cfg.ingress; {
            annotations = optionalAttrs (clusterIssuer != "") {
              "cert-manager.io/cluster-issuer" = clusterIssuer;
            };
            className = ingressClassName;
            enabled = enable;
            hosts = [
              {
                host = domain;
                paths = [
                  {
                    path = "/";
                    pathType = "ImplementationSpecific";
                  }
                ];
              }
            ];
            tls = [
              {
                hosts = [ domain ];
                secretName = "${domain}-tls";
              }
            ];
          };
          nodeSelector."kubernetes.io/hostname" = cfg.hostAffinity;
        };
    };
}
