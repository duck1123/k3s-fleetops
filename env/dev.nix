{ secrets, ... }:
let
  base-domain = "dev.kronkltd.net";
  tail-domain = "bearded-snake.ts.net";
  clusterIssuer = "letsencrypt-prod";
  nas-host = "192.168.0.124";
  nas-base = "/volume1";
  serverLocation = "Chicago IL";
  # serverLocation = "Detroit MI";
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
    # ../modules/adventureworks/default.nix
    adventureworks.enable = false;

    # ../modules/airflow/default.nix
    airflow = {
      enable = false;

      ingress = {
        inherit clusterIssuer;
        domain = "airflow.${base-domain}";
      };
    };

    # ../modules/alice-bitcoin/default.nix
    alice-bitcoin.enable = false;

    # ../modules/alice-lnd/default.nix
    alice-lnd = let user-env = "alice";
    in {
      inherit user-env;
      enable = false;
      imageVersion = "v1.10.3";
      ingress.domain = "lnd-${user-env}.dinsro.com";
    };

    # ../modules/argocd/default.nix
    argocd.enable = true;

    # ../modules/argo-workflows/default.nix
    argo-workflows = {
      enable = false;

      ingress = {
        domain = "argo-workflows.${base-domain}";
        ingressClassName = "traefik";
      };
    };

    # ../modules/authentik/default.nix
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

    # ../modules/booklore/default.nix
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
        # Optional: Enable local-only ingress using Traefik
        localIngress = {
          enable = true;
          domain = "booklore.local";
          tls.enable = false; # Set to true if you have cert-manager configured for local domains
        };
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}/Books";
      };

      storageClassName = "longhorn";
      uid = "0";
    };

    # ../modules/calibre/default.nix
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

    # ../modules/cloudbeaver/default.nix
    cloudbeaver = {
      enable = true;

      ingress = {
        domain = "cloudbeaver.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      storageClass = "longhorn";
    };

    # ../modules/crossplane/default.nix
    crossplane = {
      enable = false;
      providers.digital-ocean.enable = false;
    };

    # ../modules/dinsro/default.nix
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
      enable = false;
      logLevel = "Debug";
      ingress = {
        domain = "ersatztv.${tail-domain}";
        ingressClassName = "tailscale";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}/Videos";
      };
    };

    # ../modules/gluetun/default.nix
    gluetun = {
      enable = true;
      mullvadAccountNumber = secrets.mullvad.id;
      serverLocation = ""; # Optional: specific server location (e.g., "us-was", "se-sto")
      storageClassName = "longhorn";
    };

    # ../modules/forgejo/default.nix
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

    # ../modules/grafana/default.nix
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

    # ../modules/homer/default.nix
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

    # ../modules/jupyterhub/default.nix
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

    # ../modules/kavita/default.nix
    kavita = {
      enable = false;

      ingress = {
        domain = "kavita.${tail-domain}";
        clusterIssuer = "tailscale";
        ingressClassName = "tailscale";
        tls.enable = true;
      };
    };

    # ../modules/lidarr/default.nix
    lidarr = {
      enable = true;

      ingress = {
        domain = "lidarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      vpn = {
        enable = true;
        sharedGluetunService = "gluetun.gluetun";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      storageClassName = "longhorn";
    };

    # ../modules/radarr/default.nix
    radarr = {
      enable = false;

      ingress = {
        domain = "radarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      vpn = {
        enable = true;
        sharedGluetunService = "gluetun.gluetun";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      storageClassName = "longhorn";
    };

    # ../modules/sabnzbd/default.nix
    sabnzbd = {
      disableHostnameVerification = true;
      enable = true;

      ingress = {
        domain = "sabnzbd.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      hostWhitelist = "sabnzbd.${tail-domain},sabnzbd.sabnzbd";

      vpn = {
        enable = true;
        sharedGluetunService = "gluetun.gluetun";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      storageClassName = "longhorn";
    };

    # ../modules/prowlarr/default.nix
    prowlarr = {
      enable = true;

      ingress = {
        domain = "prowlarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      vpn = {
        enable = true;
        sharedGluetunService = "gluetun.gluetun";
      };

      storageClassName = "longhorn";
    };

    # ../modules/sonarr/default.nix
    sonarr = {
      enable = false;

      ingress = {
        domain = "sonarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      vpn = {
        enable = true;
        sharedGluetunService = "gluetun.gluetun";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      storageClassName = "longhorn";
    };

    # ../modules/whisparr/default.nix
    whisparr = {
      enable = false;

      ingress = {
        domain = "whisparr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      vpn = {
        enable = true;
        sharedGluetunService = "gluetun.gluetun";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      storageClassName = "longhorn";
    };

    # ../modules/immich/default.nix
    immich = {
      enable = false;

      database = {
        inherit (secrets.immich.database) password username;
        host = "postgresql.postgresql";
        port = 5432;
        name = "immich";
      };

      ingress = {
        domain = "immich.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}/Photos";
      };

      redis = {
        inherit (secrets.immich.redis) password;
        host = "redis.redis";
        port = 6379;
        dbIndex = 0;
      };

      storageClassName = "longhorn";
    };

    keycloak = {
      enable = false;
      ingress = {
        domain = "keycloak.dev.kronkltd.net";
        adminDomain = "keycloak-admin.dev.kronkltd.net";
        clusterIssuer = "letsencrypt-prod";
      };
    };

    # ../modules/kite/default.nix
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

    # ../modules/kyverno/default.nix
    kyverno.enable = false;

    # ../modules/lldap/default.nix
    lldap.enable = false;

    # ../modules/longhorn/default.nix
    longhorn = {
      enable = true;

      ingress = {
        domain = "longhorn.${tail-domain}";
        ingressClassName = "tailscale";
        tls.enable = true;
      };
    };

    # ../modules/mariadb/default.nix
    mariadb = {
      auth = {
        inherit (secrets.mariadb) database password replicationPassword rootPassword username;
      };

      enable = true;
      storageClass = "longhorn";

      extraDatabases = [
        {
          name = "booklore";
          username = "booklore";
          password = secrets.booklore.database.password;
        }
        # romm uses the existing 'mariadb' user, so we only need to create the database
        {
          name = "romm";
          username = "mariadb";
          password = secrets.mariadb.password;
        }
      ];
    };

    marquez = {
      domain = "marquez.${base-domain}";
      enable = false;
    };

    # ../modules/memos/default.nix
    memos = {
      enable = false;

      ingress = {
        domain = "memos.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../modules/metabase/default.nix
    metabase = {
      enable = false;

      ingress = {
        domain = "metabase.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../modules/mindsdb/default.nix
    mindsdb = {
      enable = false;

      ingress = {
        domain = "mindsdb.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../modules/minio/default.nix
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

    # ../modules/mssql/default.nix
    mssql.enable = false;

    # ../modules/n8n/default.nix
    n8n = {
      enable = false;

      ingress = {
        domain = "n8n.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../modules/nocodb/default.nix
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

    # ../modules/pihole/default.nix
    pihole = {
      enable = false;

      auth = { inherit (secrets.pihole) email password; };

      ingress = {
        domain = "pihole.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../modules/postgresql/default.nix
    postgresql = {
      auth = {
        inherit (secrets.postgresql)
          adminPassword adminUsername replicationPassword userPassword;
      };

      enable = true;
      storageClass = "longhorn";
    };

    # ../modules/redis/default.nix
    redis = {
      enable = true;
      password = secrets.redis.password;
    };

    # ../modules/romm/default.nix
    romm = {
      enable = true;

      admin = {
        username = secrets.romm.admin.username;
        password = secrets.romm.admin.password;
      };

      authSecretKey = secrets.romm.authSecretKey;

      database = {
        host = "mariadb.mariadb";
        name = "romm";
        password = secrets.mariadb.password;
        port = 3306;
        username = "mariadb";
      };

      ingress = {
        domain = "romm.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
        # Optional: Enable local-only ingress using Traefik
        localIngress = {
          enable = true;
          domain = "romm.local";
          tls.enable = false; # Set to true if you have cert-manager configured for local domains
        };
      };

      nfs = {
        enable = true;
        server = nas-host;
        libraryPath = "${nas-base}/Roms";
        assetsPath = "${nas-base}/Roms/assets";
        resourcesPath = "${nas-base}/Roms/resources";
      };
    };

    # ../modules/satisfactory/default.nix
    satisfactory.enable = false;

    # ../modules/sealed-secrets/default.nix
    sealed-secrets.enable = true;

    # ../modules/sops/default.nix
    sops.enable = true;

    # ../modules/spark/default.nix
    spark = {
      enable = false;

      ingress = {
        domain = "spark.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };
    };

    # ../modules/specter/default.nix
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
      enable = false;
      ingress = {
        inherit clusterIssuer;
        domain = "tempo.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    traefik.enable = true;
  };
}
