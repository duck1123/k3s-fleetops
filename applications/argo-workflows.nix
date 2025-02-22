{ lib, ... }: {
  applications.argo-workflows = {
    namespace = "argo-workflows";
    createNamespace = true;

    helm.releases.argo-workflows = {
      chart = lib.helm.downloadHelmChart {
        repo = "https://argoproj.github.io/argo-helm";
        chart = "argo-workflows";
        version = "0.45.0";
        chartHash = "sha256-zPvwRu7HHWqTnPvlIorg9xzggeC1plFb9caNZlxe0S0=";
      };

      values = {
        controller = {
          extraEnv = [
            # https://argo-workflows.readthedocs.io/en/latest/executor_plugins/
            {
              name = "ARGO_EXECUTOR_PLUGINS";
              value = "true";
            }
          ];
          metricsConfig = {
            enabled = true;
            port = 9090;
            portName = "metrics";
          };

          persistence = {
            archive = true;
            postgresql = {
              host = "postgresql.postgresql";
              database = "argo_workflows";
              userNameSecret = {
                name = "postresql-password";
                namespace = "postgresql";
                key = "adminUsername";
              };
              passwordSecret = {
                name = "postresql-password";
                namespace = "postgresql";
                key = "adminPassword";
              };
            };
          };

          telemetryConfig.enabled = true;
          workflowNamespaces = [ "default" "argo-workflows" ];
        };

        server = {
          authModes = [ "client" ];

          ingress = {
            enabled = true;
            ingressClassName = "traefik";
            annotations = {
              "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
              "ingress.kubernetes.io/force-ssl-redirect" = "true";
              "ingress.kubernetes.io/proxy-body-size" = "0";
              "ingress.kubernetes.io/ssl-redirect" = "true";
            };
            hosts = [ "argo-workflows.dev.kronkltd.net" ];
            tls = [{
              secretName = "argo-workflows-tls";
              hosts = [ "argo-workflows.dev.kronkltd.net" ];
            }];
          };

          workflow.serviceAccount.create = true;
        };
      };
    };
  };
}
