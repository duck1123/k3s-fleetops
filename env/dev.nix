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
    airflow.enable = false;

    # TODO: I know we can do better than this
    alice-bitcoin.enable = true;
    alice-lnd.enable = true;
    alice-specter.enable = true;

    argo-events.enable = true;
    argo-workflows.enable = true;
    authentik.enable = true;
    cloudbeaver.enable = true;
    crossplane-do-provider.enable = true;
    demo.enable = true;
    forgejo.enable = false;
    harbor.enable = false;
    homer.enable = true;
    keycloak.enable = true;
    lldap.enable = true;
    memos.enable = true;
    metabase.enable = true;
    mindsdb.enable = true;
    minio.enable = true;
    mssql.enable = false;
    openldap.enable = true;
    opentelemetry-collector.enable = true;
    postgresql.enable = false;
    redis.enable = true;
    sqlpad.enable = true;
    tempo.enable = true;
    traefik.enable = true;
  };
}
