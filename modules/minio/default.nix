{ charts, config, lib, ... }:
let
  cfg = config.services.minio;

  chart = lib.helm.downloadHelmChart {
    repo = "https://charts.bitnami.com/bitnami";
    chart = "minio";
    version = "14.8.5";
    chartHash = "sha256-zP40G0NweolTpH/Fnq9nOe486n39MqJBqQ45GwJEc1I=";
  };

  defaultNamespace = "minio";
  domain = "minio.dev.kronkltd.net";

  clusterIssuer = "letsencrypt-prod";

  defaultValues = {
    apiIngress = {
      enabled = true;
      ingressClassName = "traefik";
      hostname = "minio-api.dev.kronkltd.net";
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      tls = true;
    };

    auth = {
      existingSecret = "minio-password";
      rootUserSecretKey = "user";
    };

    ingress = {
      enabled = true;
      ingressClassName = "traefik";
      hostname = domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod";
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
        "ingress.kubernetes.io/proxy-body-size" = "0";
        "ingress.kubernetes.io/ssl-redirect" = "true";
      };
      tls = true;
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.minio = {
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
    applications.minio = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.minio = { inherit chart values; };

      resources = {
        sealedSecrets.minio-password = {
          spec = {
            encryptedData = {
              root-password =
                "AgAcT31F6yKjxL1Lxz3/l621mCDclTf8iJsE5asT68m536fCzWLB3nKc6ESMZMsEQ7eYzaZY3kClV3uHtaOQ75s2eKhdORBYIiGNGi4mxjdbFkAGHpA7owcsL038ywRg+5ak8wZJ430THqwb4owjVBH6nuVxBnInF1JvrSDlbsTW6RDCTPYEp0KCDyvFWMvCG94+qI/RvS0FIk1FQ89Z2IaghaixvvIqhgPIDhhUEgaTvwmfKX60Nu8BIwQVWt2qaZzxpWXgeEfR5rNFH7eF9rr/EKm+pYB1WZxh3mvFEMzQz9WrqXaC+bO6t26CiN9jzZmDcA0ACceQ5mCfzkP9OpysooFp37jR51HJfTuoNGr1ZVOGJDUioUJxLD7adnlbGXvqjp7nBJcDvw/N0zAxrEFpz0u1RZWbcWnG4vnab79j6B6csMXGJ7bLHG7sH8HejrQShVG7W3B6sy4BntwR3W5/SioFUM0OQmzkY9utCDl8B+fIyEwQMjSQvAX+dxKsXdfGYGwb5uTMqp/1eIr4ZxVYmsQABrHC9Y4LZjUe7llOoRwzvgRxUSbfEY0uIosC6quCSYSUpUMiUq0hqbJJS/R4fJ+skaLZga/H2dbfAbS6v/VilxK785dSY3geXRGxDEyNZ2KfPjhkIwvui/faDYgketxknHOYZ7T5iF3fuRLNBC0AXjVKXonmvuqWw3iBCOYajU2MujalxoJ0ehzGF7WNMFf5cQ==";
              user =
                "AgCZaM6/a904XN/aW7LbBCkWCrmLi1wJERXTHtvmfK1WvToshkVqYbPn4ynwCinUcRKEZFvgMAZo5FHmrurekl19pN6ZSBulvVYqBZwN7/eJ08IWYAn80x04dsSb9UySKDDryHM+Qat3z7uHzfcDgQ15L/ZllvTHydbfFC425HthtiOnKSrNzwKPVzL68VbrIwCmtZFGbFv2sABYL0ZcyhobJp2aVgKUz4zQYuOvyjuCELzIJQareCo3DJr8is2rOe3vmOouihRs+8xGLxdVW/fjIix7oeaaaDKW64HCshm3azcpFMwmUCdINo7c9jsDxqEdTQMycX59xEmYPPyZM4nlqUZdiiKX1w0N5JWBZFU2Zk6S5gaTHBkQ4w+6PV4WpCRCTNNiM+mucCVPRPcj47fur2unZz2gWp/kEXgsrfwPneoc44WjvOj32E4aFAkwVidD2ReltHs3OLr/Oc29bYY6+nMIIMwNpws4Lb4oqAHaSrqaiLCfvEOLYrk8W1Z/l4SVIB4PjvrXxdYdGf0tXdyvOQdO8bZYI9nTg4dubRRRoFzfaF9Yn3Ij6fRqa9VI2zM2m263RKP/7BVl9tb8YTY9aigqE+2xW/8H6LBdes2E4frjMvw5SvthZkZzmU36KUtq4p4hV39JRUaZlmL7/bl/If6QG/XUU+fTO6a5Nl65hdiQNSQ9+SxbkgddSbxBUWqU5NFi";
            };

            template.metadata = {
              creationTimestamp = null;
              name = "minio-password";
              namespace = cfg.namespace;
            };
          };
        };
      };
    };
  };
}
