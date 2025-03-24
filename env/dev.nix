{ nixidy, lib, ... }:
let base-domain = "dev.kronkltd.net";
in {
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
    airflow.enable = false;

    # TODO: I know we can do better than this
    alice-bitcoin.enable = false;
    alice-lnd.enable = false;
    alice-specter.enable = false;

    argocd.enable = true;
    argo-events.enable = false;
    argo-workflows.enable = false;

    authentik.enable = false;
    cert-manager.enable = true;

    cloudbeaver.enable = true;

    crossplane = {
      enable = false;
      providers.digital-ocean.enable = false;
    };

    demo.enable = false;
    dinsro.enable = false;
    forgejo.enable = false;
    harbor.enable = false;
    homer.enable = false;

    jupyterhub.enable = true;

    keycloak.enable = false;
    lldap.enable = false;

    longhorn.enable = true;

    memos.enable = false;
    metabase.enable = false;
    mindsdb.enable = false;

    minio = {
      api-domain = "minio-api.${base-domain}";
      # api-domain = "minio-api.localtest.me";
      domain = "minio.${base-domain}";
      # domain = "minio.localtest.me";
      enable = true;
      tls.enable = false;
    };

    mssql.enable = false;
    openldap.enable = false;
    opentelemetry-collector.enable = false;
    postgresql.enable = true;
    redis.enable = false;
    sealed-secrets.enable = true;

    spark = {
      enable = false;
      # domain = "spark.${base-domain}";
    };

    sqlpad.enable = false;
    tempo.enable = false;
    traefik.enable = true;
  };
}
