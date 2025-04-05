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

  clusterIssuer = "letsencrypt-prod";
  postgresql-secret = "jupyterhub-postgresql";

  hub-secret = "jupyterhub-hub2";
  hub-config = import ./config.nix { inherit (cfg) password; };
  yaml-formatter = pkgs.formats.yaml { };
  hub-json = (yaml-formatter.generate "config.yaml" hub-config).drvAttrs.value;
  hub-json-file = builtins.toFile "input.json" hub-json;
  hub-json-drv = pkgs.runCommand "convert-values-yaml" {
    nativeBuildInputs = with pkgs; [ jq yq ];
  } ''
    cat ${hub-json-file} | yq -y . > $out
  '';

  hub-yaml = builtins.readFile hub-json-drv;

  hub-secret-config = {
    apiVersion = "isindir.github.com/v1alpha3";
    kind = "SopsSecret";
    metadata = {
      name = hub-secret;
      inherit (cfg) namespace;
    };
    spec = {
      secretTemplates = [{
        name = hub-secret;
        stringData = {
          "hub.config.CryptKeeper.keys" = cfg.cryptkeeper-keys;
          "hub.config.JupyterHub.cookie_secret" = cfg.cookie-secret;
          "proxy-token" = cfg.proxy-token;
          "values.yaml" = hub-yaml;
        };
      }];
    };
  };

  hub-secret-config-yaml =
    (yaml-formatter.generate "values.yaml" hub-secret-config).drvAttrs.value;

  encrypted-secret-config = lib.encryptString {
    secretName = hub-secret;
    value = hub-secret-config-yaml;
  };

  encrypted-secret-config-object = builtins.fromJSON encrypted-secret-config;

  defaultValues = {
    hub = {
      adminUser = "admin";
      # existingSecret = hub-secret;
    };

    postgresql.auth.existingSecret = postgresql-secret;

    proxy.ingress = {
      enabled = true;
      ingressClassName = "traefik";
      hostname = cfg.domain;
      annotations = {
        "cert-manager.io/cluster-issuer" = clusterIssuer;
        "ingress.kubernetes.io/force-ssl-redirect" = "true";
      };
      tls = true;
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
in with lib; {
  options.services.${app-name} = {
    cookie-secret = mkOption {
      description = mdDoc "The cookie secret";
      type = types.str;
      default = "CHANGEME";
    };

    cryptkeeper-keys = mkOption {
      description = mdDoc "The cryptkeeper keys";
      type = types.str;
      default = "CHANGEME";
    };

    domain = mkOption {
      description = mdDoc "The ingress domain";
      type = types.str;
      default = "jupyterhub.localhost";
    };

    enable = mkEnableOption "Enable application";

    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = app-name;
    };

    password = mkOption {
      description = mdDoc "The admin user password";
      type = types.str;
      default = "CHANGEME";
    };

    proxy-token = mkOption {
      description = mdDoc "The proxy token";
      type = types.str;
      default = "CHANGEME";
    };

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    applications.${app-name} = {
      inherit (cfg) namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.${app-name} = { inherit chart values; };

      resources = {
        sealedSecrets.${postgresql-secret}.spec = {
          encryptedData = {
            password =
              "AgBfQAPO54bG0mdsU0SKtep4teQqOHb8AO1RwMIqYB7AtBU/850zbq68GGQaxqVZ1gS3pyK2ZGTzQ2f101Q2WBIZK5N7G2H0475E3+6ehRZFSolBZaR0SFzsZ6sbIupQ/DfAbtGWJdt0bQjnqK+RmopNvShe8vDpdK28AKypB65HC4b2ou76s7CuTSm3oYocrMYwN/zPY6MdzNjh8dp8R/ybUsDSRm4HE4N4jb6MPFsNb2Vy0dQgH39dgxrTgAioe/xj/QNdfHUYynZkrPcdRd9g8TU1Lcbw4jpUXQu6gWGt3Qiyw0ihzX5QoJsi7sgek/76w0sIxT6BKXgqHi8T2UtyklPWVP7bxsl8LlDUP2pdjplE5INf6FcBSXA3pUoORTsGBuZC3lRTjmi9VnhuTFRSu5ftUQ+NuOEk5oKVOOVGMuf0wkO08KIh1JnNWFkDb5W0qn32z+ePVC53YCFVcJPuNBbZLAKm/3XnUKin6M9453SXlDxPH0xwQOvY3OO8OMpZi2oQDD7UkwSe+RsD/zclULa8gqZ9vebrm0QGVjeFMB81TVNUoloJBaAHgzjdQ35IfDhYWbg9Fqk6CPlkP30xVZjY4W40AQDk9/wewVhJQ0781AyvEHnv7qVV7Px9H5f+WJdN5U2inyPZJwkKTkCOA7sq2lOz/arSTRsLRWv0PRG7c90SayoZtGeET98GmFfy0B66n+/jPpMdGJZdcan3oEbSog==";
            postgres-password =
              "AgAji2EX/A5eHpFO4dMzmymZ0iD5KGL4dExru90q9AFAsvB+wqvDeUiQNxjDos6ATMOQO8rzmESahio0OKK6uxDphZUHV7yXGDp8EplVY7y0V4aNjUnzOwuvnaI4B7pu9x21SnOUbrYHGcnmm6lDj5UgKvJxMh9lzO2/Oe7KkRLQ/NpO4lLKZnfU2az0cS5v6UwWDkPjPYYZNFc88UrmygRE6/IjME6r/qPWqCclPP0F3AlqGcfDKWx7ETm9YDAw0EQtc7kGUyCxUmRvqiSfhiVsYIHv85cX3zRXTvdwlAaIxJbnD4Z4Zk2cAzaDqdxVHpBTFRr61JZjVAcaiTShu4/J1vOgUuvyLXWDtp3w7tMdyjd6KsMEuIeZZCXoJq08JEbNHFeh2b0kHtnF5zSx+tVfSIrsZpakQI57PBBp6ZMWhkESdkT91gyCc6SNfffIMOzz3KwQQmMA6Z3IsbuDIFrgXJAuC+pvxEsqdS+7167gB8Xk8DmEMAJ3TJ4NnHvmWydakR3zOevD3aBWQa/weRfcYlkqb+cEfPxXW/9XdK5eYfJHuFf5r3+a6clkrzktr0MXFvr8gzXLN6/DI3gW+/EYMyAwiL2LcR2e8ymNz8EnJQxCZqtvLUPNye4an7l5+Unup8Swtdz2MLJmnS7CY3S7u/jNrLdMRWujbdrqqRfeYzWb8mW1Iv4weIh5Car1fIPpQCMkcc/vknKcL1IhGwRNU6qwqg==";
            username =
              "AgDC+ZtbPoXP+iiS5atYZJzD+S19ya6Th6WES4gN9GJnFycZQrEs+DXEuZf5fTNypt4p+UjshoJisw4HPe/DXtwJzvUvFaH1S2BNUAXu0QqCUeVnJAYZb8wBixwMtGpS1nj5C18Ag3Dd/3ozFNc46xUE6ueJ4/ZhOcQADnfLfafOdsfNTCfHMn3IW/3vhXTWctA6bI83Dk2IXqmUnpfa0+VfA7Bckz0KrEmK07G3CXrjcMgPWi0FaoMSp00di9n7X4L96TO7OhVOAd8ye9wMN/dIgpHathbumxd0iac7cCtC1JPM92lBGZuHdsBz2mkBVwofIsatav21TyUPh2fAzIKcXCAkShaFC3HoeO83qZazPaV0KR/00RqFpnZsGKHEvhmi66KSSKoe2o3hdKSEp6jtPAG8xSAQJqWBKGqSszwrC/Y1nkhicCGb+HaGj74mG8WCH31S6gfA/wTgs7ge0ghMlT8l70kTXPEN+HCzfkJHDKPTdOAou7vnoiTwV9DVxEL2z+z8/ZQyMSvMkLyOivpWZpbBEaUpvKjaLEPuz1ejfGaQ8N//aq6OZwT3JauVNmkIK3Mp97B5MTTaXoibLEuRMkPov6knnuLD962jM4WN4oICYiZAuOqYxVp2Y0mSz9nxjaBwGxNnM2E6xIDyof+beTNvqqkl0Wz+M/TGE+5sClxwOiMR+gbDlNC2O9AUtIWSKBtApMIjww==";
          };

          template.metadata = {
            inherit (cfg) namespace;
            name = postgresql-secret;
          };
        };

        sopsSecrets.${hub-secret} = {
          inherit (encrypted-secret-config-object) sops spec;
        };
      };

      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
