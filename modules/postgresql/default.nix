{ ageRecipients, config, lib, pkgs, ... }:
with lib;
let password-secret = "postgresql-password";
in mkArgoApp { inherit config lib; } {
  name = "postgresql";

  # https://artifacthub.io/packages/helm/bitnami/redis
  chart = lib.helm.downloadHelmChart {
    repo = "https://groundhog2k.github.io/helm-charts/";
    chart = "postgres";
    version = "1.5.8";
    chartHash = "sha256-Ev3NhEPrTWoAfFDlkYw6N88lstU2OOUJ8SEWY10pxxw=";
  };

  extraOptions = {
    auth = {
      adminPassword = mkOption {
        description = mdDoc "The admin password";
        type = types.str;
        default = "CHANGEME";
      };

      adminUsername = mkOption {
        description = mdDoc "The admin username";
        type = types.str;
        default = "admin";
      };

      replicationPassword = mkOption {
        description = mdDoc "The replication password";
        type = types.str;
        default = "CHANGEME";
      };

      userPassword = mkOption {
        description = mdDoc "The user password";
        type = types.str;
        default = "postgres";
      };
    };

    image = mkOption {
      description =
        mdDoc "The PostgreSQL image (should include pgvector for Immich)";
      type = types.str;
      default = "pgvector/pgvector:pg17";
    };

    storageClass = mkOption {
      description = mdDoc "The storage class to use for persistence";
      type = types.str;
      default = "local-path";
    };
  };

  defaultValues = cfg:
    let
      imageStr = cfg.image;
      parts = lib.splitString "/" imageStr;
      hasExplicitRegistry = lib.length parts > 2
        || (lib.length parts == 2 && lib.hasInfix "." (lib.head parts));
      registry = if hasExplicitRegistry then lib.head parts else "docker.io";
      repoAndTag = if hasExplicitRegistry then
        lib.concatStringsSep "/" (lib.tail parts)
      else
        lib.concatStringsSep "/" parts;
      tagParts = lib.splitString ":" repoAndTag;
      repository = lib.head tagParts;
      tag = if lib.length tagParts > 1 then lib.last tagParts else "latest";
    in {
      image = { inherit registry repository tag; };

      settings = {
        existingSecret = password-secret;
        superuserPassword.secretKey = "adminPassword";
      };

      storage.className = cfg.storageClass;
    };

  extraResources = cfg: {
    sopsSecrets.${password-secret} = lib.createSecret {
      inherit ageRecipients lib pkgs;
      inherit (cfg) namespace;
      secretName = password-secret;
      values = with cfg; {
        inherit (auth)
          adminPassword adminUsername replicationPassword userPassword;
      };
    };
  };
}
