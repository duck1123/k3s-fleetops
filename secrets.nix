{config, lib, pkgs, ... }: {
  imports = [
    ./secrets-module.nix
  ];

  secrets = {
    "nocodb.minio.bucketName" = {

    };
  };

  nocodb = {
    minio = {
      bucketName = {
        keepassPath = [
          "Kubernetes"
          "minio-bucketName"
        ];
      };
    };
  };
}
