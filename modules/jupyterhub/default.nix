{ config, lib, pkgs, ... }:
let
  app-name = "jupyterhub";

  cfg = config.services."${app-name}";

  # https://artifacthub.io/packages/helm/bitnami/jupyterhub
  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../charts/jupyterhub-8.1.5.tgz;
    chartName = "jupyterhub";
  };

  defaultNamespace = "jupyterhub";
  # domain = "jupyterhub.localhost";
  domain = "jupyterhub.dev.kronkltd.net";
  tls-secret-name = "jupyterhub-tls";
  clusterIssuer = "letsencrypt-prod";
  postgresql-secret = "postgresql-credentials";

  defaultValues = {
    hub.adminUser = "admin";

    postgresql.auth.existingSecret = postgresql-secret;

    proxy.ingress = {
      enabled = true;
      ingressClassName = "traefik";
      hostname = domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      tls = true;
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services."${app-name}" = {
    enable = mkEnableOption "Enable application";
    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = defaultNamespace;
    };

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    applications."${app-name}" = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases."${app-name}" = { inherit chart values; };

      resources.sealedSecrets."${postgresql-secret}".spec = {
        encryptedData = {
          password =
            "AgCqz5TBDAjidSpDKisCY3R9/TwjZEtbTSWphuEfayRPhrvUe+uMftte5JtVqx2IOW7iRQUEUP8QsicHkQUiNKizqBJb9+5ekpmrquBuz12zpiMvCSH7E2aqFt/B/CZbvVYldecwn+2IXMbADHjcPY1SGzPvwGNFdqyAHhyE3dO+TxQwNTdw041FbptIa2tOq11Fod3pPAJa3niBdVWYYu2K55JJgAUzLl6qOyNDOCE21vRMkTBXn55IviO+rc4mLgdGMdEKIZkNTmTXK2m0Pm/XUW7s2CCpw/M6DxIgk2xZ+sJC1qhKnZ8+06JtsMrpw6W8zPxb5/fd6lNj5uGJUkWzdLDvV/IbNbcfD9QlXPsntHhbLJlpKXD7hvjVqEc/yHqAH93teAsOs2XWBV0jN53osdEgTKz8pvssSK9xXoQMCQt8yAh4YWqOaeXNGGkaNVMGQWWYgugqHbim+JAjFdLi4Hn0KTtLnClTtzazsBTuSUzJWx7BrV3sZLXPqtRCBAGgPuk1bRUi89pBPeQTByj1JZtsDRTZ4Ts86HrjKZ7ZgQQIGdzOtSSZ9amS4WEvV0O8xOLpigJgB1FJqQEomwTZsp1wKbCVTmtduN84Jl9nymA1xzAgXMiMEItayn9cRIBDX3nDBw7SQoH1qvkFrjTCXvi5c77CWy5YS8uhDsgxb1IP5Hukq66b70RM8+LL2i5aGYHXit386nzA25qPdmYTSvFxGw==";
          username =
            "AgDFpOugLiVgK3fd+1xzzoTYcDMpHbs7EEcRI2ElmOBwmMacaixsgcScAigyE+rpTe+AzHp8uIQGBsN4xbTX6VS+hRyAuUP9sjl/YZLtsbRbKjlSAQUDbYQquV9Hk9ghmS7srNW79+B8QGSeZ3GFVC8drMTyKs27zW383DSDPhxuzmfj1DvzXnJh9A5NdlocMSOeGW4Jgez3ZB0okpbd2r3BIZ4O5l3rOju0zWiE5t3kSLfV+kXWFkq6/h8MGrBxVytJktfkrdXYIxNl5Gj/AN6uKSDqJWnE0ZUQ7DxY+Jhuguw3ExGb1u+/8lVbz/v/VwVtq9QSCKOZi4jbZtoaUMpXYySv3FyXsVnxZkLBsz9Pttp1oHG/+xOFJbZ6sKTb7Kp1ZTy+a1E95sVFSyHTENFgsH6aoiCshZRe587hG3hxsPebAG/fdh+Ntdpr+Bxkc7TdJxsV0Itx1GPoA3E40uGy4cDk2p9xU9yTG8xZYxeF2rOpnXv3efRBS8ZFxkTC8Ekkdlgwy4iZ/WN2TCBOXEgZuZMUMDS6+xF83u1yKSfNubfvOrqqpcCIzsKqjWdoK8fcfnaWVKkpZujxPWDbYBbOxXq/Bp6SeVh5cjlyOnjqxZs527NSBwLrGVmp+54lvTBrdQYhHs/F37X6AvP3nCFkEYi9fSJJ08LNSEOMoNPZl5RiIJ/6iY17z30Vjmh1yPODnJzfD8MO4g==";
        };

        template.metadata = {
          inherit namespace;
          name = postgresql-secret;
        };
      };

      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
