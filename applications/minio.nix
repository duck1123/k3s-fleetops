{ ... }:
{
  flake.nixidyApps.minio =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    with lib;
    let
      password-secret = "minio-password";
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
        name = "minio";

        sopsSecrets = cfg: {
          ${password-secret} = {
            password = cfg.password;
          };
        };

        # https://artifacthub.io/packages/helm/bitnami/minio
        chart = helm.downloadHelmChart {
          repo = "https://charts.bitnami.com/bitnami";
          chart = "minio";
          version = "17.0.21";
          chartHash = "sha256-bv1Mb/Gxu97ncIqS2/81vJC/svStdOWLocXxwbnd+hU=";
        };

        uses-ingress = true;

        extraOptions = {
          ingress.api-domain = mkOption {
            description = mdDoc "The ingress domain for the API";
            type = types.str;
            default = defaultApiDomain;
          };

          password = mkOption {
            description = mdDoc "The password";
            type = types.str;
            default = "CHANGEME";
          };
        };

        defaultValues = cfg: {
          auth = {
            existingSecret = password-secret;
            rootUserSecretKey = "user";
            rootPasswordSecretKey = "root-password";
          };

          console = {
            enabled = true;

            ingress = with cfg.ingress; {
              inherit ingressClassName;
              enabled = true;
              hostname = api-domain;
            };
          };

          ingress = with cfg.ingress; {
            inherit ingressClassName;
            enabled = true;
            hostname = domain;
            tls = tls.enable;
          };

          persistence.storageClass = cfg.storageClassName;
        };

      };
}
