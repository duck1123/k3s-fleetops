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
    adventureworks.enable = false;

    # TODO: I know we can do better than this
    alice-bitcoin.enable = false;
    alice-specter.enable = false;

    argo-events.enable = true;
    argo-workflows.enable = false;
    authentik.enable = false;
    cloudbeaver.enable = true;
    demo.enable = true;
    dinsro.enable = false;
    forgejo.enable = false;
    harbor.enable = false;
    homer.enable = false;
    keycloak.enable = false;
    lldap.enable = false;
    memos.enable = false;
    metabase.enable = false;
    mindsdb.enable = false;
    minio.enable = true;
    mssql.enable = false;
    opentelemetry-collector.enable = false;
    postgresql.enable = false;
    redis.enable = false;
    sqlpad.enable = false;
    tempo.enable = true;
    traefik.enable = true;
  };
}
