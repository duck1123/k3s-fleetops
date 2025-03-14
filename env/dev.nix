{ nixidy, lib, ... }: {
  nixidy = {
    defaults.syncPolicy.autoSync = {
      enabled = true;
      prune = true;
      selfHeal = true;
    };

    target = {
      branch = "master";
      repository = "https://github.com/duck1123/k3s-fleetops.git";
      rootPath = "./manifests/dev";
    };
  };

  services = {
    adventureworks.enable = true;
    argo-events.enable = true;
    argo-workflows.enable = false;
    authentik.enable = true;
    cloudbeaver.enable = true;
    forgejo.enable = false;
    homer.enable = true;
    lldap.enable = true;
    metabase.enable = false;
    minio.enable = true;
    mssql.enable = false;
    postgresql.enable = false;
    redis.enable = true;
  };
}
