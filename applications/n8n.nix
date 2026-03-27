{ ... }:
{
  flake.nixidyApps.n8n =
    {
      config,
      lib,
      self,
      pkgs,
      ...
    }:
    with lib;
    let
      encryption-secret = "n8n-encryption-key";
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
        name = "n8n";

        # https://artifacthub.io/packages/helm/community-charts/n8n
        chart = lib.helm.downloadHelmChart {
          repo = "https://community-charts.github.io/helm-charts";
          chart = "n8n";
          version = "1.16.33";
          chartHash = "sha256-fmbF78bCn+X+7SvFtSTtHbDVxaP6my/QGSBbN7OIdeM=";
        };

        uses-ingress = true;

        extraOptions = {
          encryptionKey = mkOption {
            description = mdDoc ''
              Value for Kubernetes secret key `N8N_ENCRYPTION_KEY`. When non-empty, a SopsSecret
              is created and the chart uses `existingEncryptionKeySecret` instead of Helm-managed
              `n8n-encryption-key-secret-v2`. Use the same key when restoring an existing instance.
            '';
            type = types.str;
            default = "";
          };
        };

        sopsSecrets =
          cfg:
          optionalAttrs (cfg.encryptionKey != "") {
            ${encryption-secret}.N8N_ENCRYPTION_KEY = cfg.encryptionKey;
          };

        defaultValues =
          cfg:
          {
            ingress = with cfg.ingress; {
              annotations."cert-manager.io/cluster-issuer" = clusterIssuer;
              enabled = true;
              className = ingressClassName;

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

              tls = [
                {
                  secretName = "n8n-tls";
                  hosts = [ domain ];
                }
              ];
            };

            # Match the Tailscale / cert-manager hostname so redirects, cookies, and webhooks work.
            main = {
              editorBaseUrl = "https://${cfg.ingress.domain}";
              extraEnvVars = {
                N8N_HOST = cfg.ingress.domain;
                N8N_PROTOCOL = "https";
                WEBHOOK_URL = "https://${cfg.ingress.domain}/";
              };
            };
          }
          // optionalAttrs (cfg.hostAffinity != null) {
            nodeSelector."kubernetes.io/hostname" = cfg.hostAffinity;
          }
          // optionalAttrs (cfg.encryptionKey != "") {
            existingEncryptionKeySecret = encryption-secret;
            encryptionKey = "";
          };
      };
}
