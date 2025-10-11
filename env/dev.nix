{ secrets, ... }:
let
  base-domain = "dev.kronkltd.net";
  tail-domain = "bearded-snake.ts.net";
  clusterIssuer = "letsencrypt-prod";
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
    # file://../modules/adventureworks/default.nix
    adventureworks.enable = false;

    # file://../modules/airflow/default.nix
    airflow = {
      enable = false;

      ingress = {
        inherit clusterIssuer;
        domain = "airflow.${base-domain}";
      };
    };

    # file://../modules/alice-bitcoin/default.nix
    alice-bitcoin.enable = false;

    # file://../modules/alice-lnd/default.nix
    alice-lnd = let user-env = "alice";
    in {
      inherit user-env;
      enable = false;
      imageVersion = "v1.10.3";
      ingress.domain = "lnd-${user-env}.dinsro.com";
    };

    # file://../modules/argocd/default.nix
    argocd.enable = true;

    # file://../modules/argo-workflows/default.nix
    argo-workflows = {
      enable = false;

      ingress = {
        domain = "argo-workflows.${base-domain}";
        ingressClassName = "traefik";
      };
    };

    # file://../modules/authentik/default.nix
    authentik = {
      inherit (secrets.authentik) secret-key;
      enable = false;

      ingress = {
        inherit clusterIssuer;
        domain = "authentik.${base-domain}";
        ingressClassName = "traefik";
      };

      postgresql = {
        inherit (secrets.authentik.postgresql)
          password postgres-password replicationPassword;
        host = "postgreql.postgreql";
      };
    };

    # file://../modules/booklore/default.nix
    booklore = {
      enable = true;

      database = {
        host = "mariadb.mariadb";
        password = secrets.booklore.database.password;
        port = 3306;
        name = "booklore";
        username = "booklore";
      };

      gid = "0";

      ingress = {
        domain = "booklore.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = true;
        server = "192.168.0.124";
        path = "/volume1/Books";
      };

      storageClassName = "longhorn";
      uid = "0";
    };

    # file://../modules/calibre/default.nix
    calibre = {
      enable = false;

      ingress = {
        domain = "calibre.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      # storageClass = "longhorn";
    };

    cert-manager.enable = true;

    # file://../modules/cloudbeaver/default.nix
    cloudbeaver = {
      enable = true;

      ingress = {
        domain = "cloudbeaver.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      storageClass = "longhorn";
    };

    # file://../modules/crossplane/default.nix
    crossplane = {
      enable = false;
      providers.digital-ocean.enable = false;
    };

    # file://../modules/dinsro/default.nix
    dinsro = {
      enable = false;

      ingress = {
        clusterIssuer = "tailscale";
        domain = "dinsro.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../modules/ersatztv/default.nix
    ersatztv = {
      enable = true;
      logLevel = "Debug";
      ingress = {
        domain = "ersatztv.${tail-domain}";
        ingressClassName = "tailscale";
      };

      nfs = {
        enable = true;
        server = "192.168.0.124";
        path = "/volume1/Videos";
      };
    };

    # file://../modules/forgejo/default.nix
    forgejo = {
      admin = { inherit (secrets.forgejo.admin) password username; };
      enable = false;

      ingress = {
        domain = "forgejo.${tail-domain}";
        ingressClassName = "tailscale";
      };

      postgresql = {
        inherit (secrets.forgejo.postgresql)
          adminPassword adminUsername replicationPassword userPassword;
      };

      storageClass = "longhorn";
    };

    # file://../modules/grafana/default.nix
    grafana = {
      enable = false;

      ingress = {
        clusterIssuer = "tailscale";
        domain = "grafana.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    harbor-nix = {
      domain = "harbor.${base-domain}";
      enable = false;
    };

    # file://../modules/homer/default.nix
    homer = {
      codeserver.ingress = {
        domain = "codeserver.${tail-domain}";
        enable = true;
      };

      enable = false;

      ingress = {
        domain = "homer.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # file://../modules/jupyterhub/default.nix
    jupyterhub = {
      enable = false;
      inherit (secrets.jupyterhub)
        cookieSecret cryptkeeperKeys password proxyToken;

      ingress = {
        domain = "jupyterhub.${tail-domain}";
        clusterIssuer = "tailscale";
        ingressClassName = "tailscale";
        tls.enable = true;
      };

      postgresql = { inherit (secrets.jupyterhub.postgresql) adminPassword; };
    };

    # file://../modules/kavita/default.nix
    kavita = {
      enable = false;

      ingress = {
        domain = "kavita.${tail-domain}";
        clusterIssuer = "tailscale";
        ingressClassName = "tailscale";
        tls.enable = true;
      };
    };

    keycloak = {
      enable = false;
      ingress = {
        domain = "keycloak.dev.kronkltd.net";
        adminDomain = "keycloak-admin.dev.kronkltd.net";
        clusterIssuer = "letsencrypt-prod";
      };
    };

    # file://../modules/kite/default.nix
    kite = {
      enable = true;
      inherit (secrets.kite) encryptKey jwtSecret;

      ingress = {
        domain = "kite.${tail-domain}";
        clusterIssuer = "tailscale";
        ingressClassName = "tailscale";
        tls.enable = true;
      };
    };

    # file://../modules/kyverno/default.nix
    kyverno.enable = false;

    # file://../modules/lldap/default.nix
    lldap.enable = false;

    # file://../modules/longhorn/default.nix
    longhorn = {
      enable = true;

      ingress = {
        domain = "longhorn.${tail-domain}";
        ingressClassName = "tailscale";
        tls.enable = true;
      };
    };

    # file://../modules/mariadb/default.nix
    mariadb = {
      auth = {
        inherit (secrets.mariadb) database password rootPassword username;
      };

      enable = true;
      storageClass = "longhorn";
    };

    marquez = {
      domain = "marquez.${base-domain}";
      enable = false;
    };

    # file://../modules/memos/default.nix
    memos = {
      enable = false;

      ingress = {
        domain = "memos.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # file://../modules/metabase/default.nix
    metabase = {
      enable = false;

      ingress = {
        domain = "metabase.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # file://../modules/mindsdb/default.nix
    mindsdb = {
      enable = false;

      ingress = {
        domain = "mindsdb.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # file://../modules/minio/default.nix
    minio = {
      enable = false;

      ingress = {
        api-domain = "api-minio.${tail-domain}";
        domain = "minio.${tail-domain}";
        clusterIssuer = "tailscale";
        ingressClassName = "tailscale";
        tls.enable = true;
      };

      values.defaultBuckets = "my-default-bucket";
    };

    # file://../modules/mssql/default.nix
    mssql.enable = false;

    # file://../modules/n8n/default.nix
    n8n = {
      enable = false;

      ingress = {
        domain = "n8n.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # file://../modules/nocodb/default.nix
    nocodb = {
      enable = false;

      ingress = {
        domain = "nocodb.${tail-domain}";
        ingressClassName = "tailscale";
      };

      databases = {
        minio = {
          inherit (secrets.nocodb.minio)
            bucketName endpoint region rootPassword rootUser;
        };
        postgresql = {
          inherit (secrets.nocodb.postgresql)
            database password postgresPassword replicationPassword username;
        };
        redis = { inherit (secrets.nocodb.redis) password; };
      };
    };

    # file://../modules/pihole/default.nix
    pihole = {
      enable = false;

      auth = { inherit (secrets.pihole) email password; };

      ingress = {
        domain = "pihole.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # file://../modules/postgresql/default.nix
    postgresql = {
      auth = {
        inherit (secrets.postgresql)
          adminPassword adminUsername replicationPassword userPassword;
      };

      enable = true;
      storageClass = "longhorn";
    };

    # file://../modules/redis/default.nix
    redis = {
      enable = false;
      password = secrets.redis.password;
    };

    # file://../modules/satisfactory/default.nix
    satisfactory.enable = false;

    # file://../modules/sealed-secrets/default.nix
    sealed-secrets.enable = true;

    # file://../modules/sops/default.nix
    sops.enable = true;

    # file://../modules/spark/default.nix
    spark = {
      enable = false;

      ingress = {
        domain = "spark.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };
    };

    # file://../modules/specter/default.nix
    specter = {
      enable = false;

      ingress = {
        domain = "specter.${tail-domain}";
        ingressClassName = "tailscale";
      };

      namespace = "specter";
    };

    tailscale = {
      enable = true;
      oauth = { inherit (secrets.tailscale) authKey clientId clientSecret; };
    };

    tempo = {
      enable = true;
      ingress = {
        inherit clusterIssuer;
        domain = "tempo.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    traefik.enable = true;
  };
}
