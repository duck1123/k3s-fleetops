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
  postgresql-secret = "jupyterhub-postgresql";

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
            "AgBfQAPO54bG0mdsU0SKtep4teQqOHb8AO1RwMIqYB7AtBU/850zbq68GGQaxqVZ1gS3pyK2ZGTzQ2f101Q2WBIZK5N7G2H0475E3+6ehRZFSolBZaR0SFzsZ6sbIupQ/DfAbtGWJdt0bQjnqK+RmopNvShe8vDpdK28AKypB65HC4b2ou76s7CuTSm3oYocrMYwN/zPY6MdzNjh8dp8R/ybUsDSRm4HE4N4jb6MPFsNb2Vy0dQgH39dgxrTgAioe/xj/QNdfHUYynZkrPcdRd9g8TU1Lcbw4jpUXQu6gWGt3Qiyw0ihzX5QoJsi7sgek/76w0sIxT6BKXgqHi8T2UtyklPWVP7bxsl8LlDUP2pdjplE5INf6FcBSXA3pUoORTsGBuZC3lRTjmi9VnhuTFRSu5ftUQ+NuOEk5oKVOOVGMuf0wkO08KIh1JnNWFkDb5W0qn32z+ePVC53YCFVcJPuNBbZLAKm/3XnUKin6M9453SXlDxPH0xwQOvY3OO8OMpZi2oQDD7UkwSe+RsD/zclULa8gqZ9vebrm0QGVjeFMB81TVNUoloJBaAHgzjdQ35IfDhYWbg9Fqk6CPlkP30xVZjY4W40AQDk9/wewVhJQ0781AyvEHnv7qVV7Px9H5f+WJdN5U2inyPZJwkKTkCOA7sq2lOz/arSTRsLRWv0PRG7c90SayoZtGeET98GmFfy0B66n+/jPpMdGJZdcan3oEbSog==";
          postgres-password =
            "AgAji2EX/A5eHpFO4dMzmymZ0iD5KGL4dExru90q9AFAsvB+wqvDeUiQNxjDos6ATMOQO8rzmESahio0OKK6uxDphZUHV7yXGDp8EplVY7y0V4aNjUnzOwuvnaI4B7pu9x21SnOUbrYHGcnmm6lDj5UgKvJxMh9lzO2/Oe7KkRLQ/NpO4lLKZnfU2az0cS5v6UwWDkPjPYYZNFc88UrmygRE6/IjME6r/qPWqCclPP0F3AlqGcfDKWx7ETm9YDAw0EQtc7kGUyCxUmRvqiSfhiVsYIHv85cX3zRXTvdwlAaIxJbnD4Z4Zk2cAzaDqdxVHpBTFRr61JZjVAcaiTShu4/J1vOgUuvyLXWDtp3w7tMdyjd6KsMEuIeZZCXoJq08JEbNHFeh2b0kHtnF5zSx+tVfSIrsZpakQI57PBBp6ZMWhkESdkT91gyCc6SNfffIMOzz3KwQQmMA6Z3IsbuDIFrgXJAuC+pvxEsqdS+7167gB8Xk8DmEMAJ3TJ4NnHvmWydakR3zOevD3aBWQa/weRfcYlkqb+cEfPxXW/9XdK5eYfJHuFf5r3+a6clkrzktr0MXFvr8gzXLN6/DI3gW+/EYMyAwiL2LcR2e8ymNz8EnJQxCZqtvLUPNye4an7l5+Unup8Swtdz2MLJmnS7CY3S7u/jNrLdMRWujbdrqqRfeYzWb8mW1Iv4weIh5Car1fIPpQCMkcc/vknKcL1IhGwRNU6qwqg==";
          username =
            "AgDC+ZtbPoXP+iiS5atYZJzD+S19ya6Th6WES4gN9GJnFycZQrEs+DXEuZf5fTNypt4p+UjshoJisw4HPe/DXtwJzvUvFaH1S2BNUAXu0QqCUeVnJAYZb8wBixwMtGpS1nj5C18Ag3Dd/3ozFNc46xUE6ueJ4/ZhOcQADnfLfafOdsfNTCfHMn3IW/3vhXTWctA6bI83Dk2IXqmUnpfa0+VfA7Bckz0KrEmK07G3CXrjcMgPWi0FaoMSp00di9n7X4L96TO7OhVOAd8ye9wMN/dIgpHathbumxd0iac7cCtC1JPM92lBGZuHdsBz2mkBVwofIsatav21TyUPh2fAzIKcXCAkShaFC3HoeO83qZazPaV0KR/00RqFpnZsGKHEvhmi66KSSKoe2o3hdKSEp6jtPAG8xSAQJqWBKGqSszwrC/Y1nkhicCGb+HaGj74mG8WCH31S6gfA/wTgs7ge0ghMlT8l70kTXPEN+HCzfkJHDKPTdOAou7vnoiTwV9DVxEL2z+z8/ZQyMSvMkLyOivpWZpbBEaUpvKjaLEPuz1ejfGaQ8N//aq6OZwT3JauVNmkIK3Mp97B5MTTaXoibLEuRMkPov6knnuLD962jM4WN4oICYiZAuOqYxVp2Y0mSz9nxjaBwGxNnM2E6xIDyof+beTNvqqkl0Wz+M/TGE+5sClxwOiMR+gbDlNC2O9AUtIWSKBtApMIjww==";
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
