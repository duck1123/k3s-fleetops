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
    cloudbeaver.enable = true;
    forgejo.enable = false;
    metabase.enable = false;
    minio.enable = true;
    mssql.enable = false;
    postgresql.enable = false;
  };
}
