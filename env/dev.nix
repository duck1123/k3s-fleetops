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

    jupyterhub = {
      enable = true;
      # domain = "jupyterhub.${base-domain}";
      domain = "jupyterhub.localhost";
      ssl = false;

      # FIXME: very naughty config
      cookieSecret = "6b8150585353762fdaeb7960d87a7b9eb065b912e12a39f4581cbfa405e368f2";
      cryptkeeperKeys = "OTBjM2NjMzFmMmQyYzIzZmU5OWY1NTQ5MDJiYmYyMDY3MGY0NGI0Zjc0MzE0OGZkODFkNmFiMzk0MTdkY2IzZA";
      password = "v2ryCkHmGG";
      proxyToken = "izFoas2HBfSYhG0wFXUY2S0IaRXJ32vK";
    };

    keycloak.enable = false;

    kyverno.enable = false;

    lldap.enable = false;

    longhorn.enable = false;

    memos.enable = false;
    metabase.enable = false;
    mindsdb.enable = false;

    minio = {
      api-domain = "minio-api.${base-domain}";
      # api-domain = "minio-api.localtest.me";
      domain = "minio.${base-domain}";
      # domain = "minio.localtest.me";
      enable = true;
      tls.enable = true;
    };

    mssql.enable = false;
    openldap.enable = false;
    opentelemetry-collector.enable = false;
    postgresql.enable = true;
    redis.enable = false;
    sealed-secrets.enable = true;

    sops.enable = true;

    spark = {
      enable = true;
      # domain = "spark.${base-domain}";
    };

    sqlpad.enable = false;
    tempo.enable = false;
    traefik.enable = true;
  };
}
