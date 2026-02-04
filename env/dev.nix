{ secrets, ... }:
let
  base-domain = "dev.kronkltd.net";
  tail-domain = "bearded-snake.ts.net";
  clusterIssuer = "letsencrypt-prod";
  nas-host = "192.168.0.124";
  nas-base = "/volume1";

  # Helper function to generate database entries for *arr applications
  # Takes a list of app configs and generates main + log databases
  arrDatabases =
    apps:
    builtins.concatLists (
      map (app: [
        {
          name = if app.name == "prowlarr" then "${app.name}-main" else app.name;
          username = app.name;
          password = secrets.postgresql.userPassword;
        }
        {
          name = if app.name == "prowlarr" then "${app.name}-log" else "${app.name}-log";
          username = app.name;
          password = secrets.postgresql.userPassword;
        }
      ]) apps
    );
in
{
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
    # ../applications/adventureworks/default.nix
    adventureworks.enable = false;

    # ../applications/airflow/default.nix
    airflow = {
      enable = false;

      ingress = {
        inherit clusterIssuer;
        domain = "airflow.${base-domain}";
      };
    };

    # ../applications/alice-bitcoin/default.nix
    alice-bitcoin.enable = false;

    # ../applications/alice-lnd/default.nix
    alice-lnd =
      let
        user-env = "alice";
      in
      {
        inherit user-env;
        enable = false;
        imageVersion = "v1.10.3";
        ingress.domain = "lnd-${user-env}.dinsro.com";
      };

    # ../applications/argocd/default.nix
    argocd.enable = true;

    # ../applications/argo-workflows/default.nix
    argo-workflows = {
      enable = false;

      ingress = {
        domain = "argo-workflows.${base-domain}";
        ingressClassName = "traefik";
      };
    };

    # ../applications/authentik/default.nix
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
          password
          postgres-password
          replicationPassword
          ;
        host = "postgreql.postgreql";
      };
    };

    # ../applications/booklore/default.nix
    booklore = {
      enable = false;

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

    # ../applications/calibre/default.nix
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

    # ../applications/amd-gpu-device-plugin/default.nix
    amd-gpu-device-plugin.enable = true;

    # ../applications/cloudbeaver/default.nix
    cloudbeaver = {
      enable = true;

      ingress = {
        domain = "cloudbeaver.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      storageClass = "longhorn";
    };

    # ../applications/crossplane/default.nix
    crossplane = {
      enable = false;
      providers.digital-ocean.enable = false;
    };

    # ../applications/dinsro/default.nix
    dinsro = {
      enable = false;

      ingress = {
        clusterIssuer = "tailscale";
        domain = "dinsro.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../applications/dozzle/default.nix
    dozzle = {
      enable = false;

      ingress = {
        domain = "dozzle.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };
    };

    # ../applications/ersatztv/default.nix
    ersatztv = {
      enable = true;
      # logLevel = "Debug";
      ingress = {
        domain = "ersatztv.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}/Videos";
      };

      enableGPU = false; # Don't request exclusive GPU resource
      sharedGPU = true; # Enable shared GPU mode (mount /dev/dri for time-sharing)
    };

    # ../applications/gluetun/default.nix
    gluetun = {
      controlServer = { inherit (secrets.gluetun) password username; };
      enable = true;
      mullvadAccountNumber = secrets.mullvad.id;
      storageClassName = "longhorn";
    };

    # ../applications/forgejo/default.nix
    forgejo = {
      admin = { inherit (secrets.forgejo.admin) password username; };
      enable = false;

      ingress = {
        domain = "forgejo.${tail-domain}";
        ingressClassName = "tailscale";
      };

      postgresql = {
        inherit (secrets.forgejo.postgresql)
          adminPassword
          adminUsername
          replicationPassword
          userPassword
          ;
      };

      storageClass = "longhorn";
    };

    # ../applications/grafana/default.nix
    grafana = {
      enable = true;

      adminPassword = secrets.grafana.password or "";

      ingress = {
        clusterIssuer = "tailscale";
        domain = "grafana.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../applications/prometheus/default.nix
    prometheus = {
      enable = true;

      # Additional scrape configs for monitoring other hosts
      # Example format (uncomment and modify as needed):
      # additionalScrapeConfigs = [
      #   {
      #     job_name = "node-exporter-remote";
      #     static_configs = [
      #       {
      #         targets = [
      #           "host1.${tail-domain}:9100"
      #           "host2.${tail-domain}:9100"
      #         ];
      #         labels = {
      #           instance = "remote-host";
      #         };
      #       }
      #     ];
      #   }
      # ];
      additionalScrapeConfigs = [ ];

      alertmanager = {
        enabled = true;
      };
    };

    harbor-nix = {
      domain = "harbor.${base-domain}";
      enable = false;
    };

    # ../applications/homer/default.nix
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

    # ../applications/immich/default.nix
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

    # ../applications/jupyterhub/default.nix
    jupyterhub = {
      enable = false;
      inherit (secrets.jupyterhub)
        cookieSecret
        cryptkeeperKeys
        password
        proxyToken
        ;

      ingress = {
        domain = "jupyterhub.${tail-domain}";
        clusterIssuer = "tailscale";
        ingressClassName = "tailscale";
        tls.enable = true;
      };

      postgresql = { inherit (secrets.jupyterhub.postgresql) adminPassword; };
    };

    # ../applications/kavita/default.nix
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

    # ../applications/kite/default.nix
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

    # ../applications/kyverno/default.nix
    kyverno.enable = false;

    # ../applications/lidarr/default.nix
    lidarr = {
      enable = false;

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

      database = {
        enable = true;
        host = "postgresql.postgresql";
        port = 5432;
        name = "lidarr";
        username = "lidarr";
        password = secrets.postgresql.userPassword;
      };

      replicas = 0;
      storageClassName = "longhorn";
    };

    # ../applications/lldap/default.nix
    lldap.enable = false;

    # ../applications/longhorn/default.nix
    longhorn = {
      enable = true;

      ingress = {
        domain = "longhorn.${tail-domain}";
        ingressClassName = "tailscale";
        tls.enable = true;
      };
    };

    # ../applications/mariadb/default.nix
    mariadb = {
      auth = {
        inherit (secrets.mariadb)
          database
          password
          replicationPassword
          rootPassword
          username
          ;
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

    # ../applications/memos/default.nix
    memos = {
      enable = false;

      ingress = {
        domain = "memos.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../applications/metabase/default.nix
    metabase = {
      enable = false;

      ingress = {
        domain = "metabase.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../applications/mindsdb/default.nix
    mindsdb = {
      enable = false;

      ingress = {
        domain = "mindsdb.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../applications/minio/default.nix
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

    # ../applications/mssql/default.nix
    mssql.enable = false;

    # ../applications/n8n/default.nix
    n8n = {
      enable = false;

      ingress = {
        domain = "n8n.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../applications/nocodb/default.nix
    nocodb = {
      enable = false;

      ingress = {
        domain = "nocodb.${tail-domain}";
        ingressClassName = "tailscale";
      };

      databases = {
        minio = {
          inherit (secrets.nocodb.minio)
            bucketName
            endpoint
            region
            rootPassword
            rootUser
            ;
        };
        postgresql = {
          inherit (secrets.nocodb.postgresql)
            database
            password
            postgresPassword
            replicationPassword
            username
            ;
        };
        redis = { inherit (secrets.nocodb.redis) password; };
      };
    };

    # ../applications/pihole/default.nix
    pihole = {
      enable = false;

      auth = { inherit (secrets.pihole) email password; };

      ingress = {
        domain = "pihole.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    # ../applications/postgresql/default.nix
    postgresql = {
      auth = {
        inherit (secrets.postgresql)
          adminPassword
          adminUsername
          replicationPassword
          userPassword
          ;
      };

      enable = true;
      storageClass = "longhorn";

      extraDatabases = arrDatabases [
        { name = "prowlarr"; }
        { name = "sonarr"; }
        { name = "radarr"; }
        { name = "lidarr"; }
        { name = "whisparr"; }
      ];
    };

    # ../applications/prowlarr/default.nix
    prowlarr = {
      database = {
        enable = true;
        host = "postgresql.postgresql";
        port = 5432;
        name = "prowlarr-main";
        username = "prowlarr";
        password = secrets.postgresql.userPassword;
      };

      enable = false;

      ingress = {
        domain = "prowlarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      replicas = 0;
    };

    # ../applications/qbittorrent/default.nix
    qbittorrent = {
      enable = false;

      ingress = {
        domain = "qbittorrent.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      webui = { inherit (secrets.qbittorrent) password username; };
    };

    # ../applications/radarr/default.nix
    radarr = {
      database = {
        enable = false;
        host = "postgresql.postgresql";
        port = 5432;
        name = "radarr";
        username = "radarr";
        password = secrets.postgresql.userPassword;
      };

      enable = false;

      # Use a specific stable version to avoid v6.0.4.10291 DryIoc bug
      # Version 5.22.4.9896-ls272 is a known stable release
      image = "linuxserver/radarr:5.22.4.9896-ls272";

      ingress = {
        domain = "radarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      replicas = 1;
      storageClassName = "longhorn";
    };

    # ../applications/redis/default.nix
    redis = {
      enable = true;
      password = secrets.redis.password;
    };

    # ../applications/romm/default.nix
    romm = {
      enable = false;

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

    # ../applications/satisfactory/default.nix
    satisfactory.enable = false;

    # ../applications/sabnzbd/default.nix
    sabnzbd = {
      enable = true;

      ingress = {
        domain = "sabnzbd.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      replicas = 1;
    };

    # ../applications/sealed-secrets/default.nix
    sealed-secrets.enable = true;

    # ../applications/sonarr/default.nix
    sonarr = {
      database = {
        enable = true;
        host = "postgresql.postgresql";
        port = 5432;
        name = "sonarr";
        username = "sonarr";
        password = secrets.postgresql.userPassword;
      };

      enable = true;

      ingress = {
        domain = "sonarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      replicas = 1;
    };

    # ../applications/sops/default.nix
    sops.enable = true;

    # ../applications/spark/default.nix
    spark = {
      enable = false;

      ingress = {
        domain = "spark.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };
    };

    # ../applications/specter/default.nix
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

    # ../applications/stashapp/default.nix
    stashapp = {
      enable = true;

      ingress = {
        domain = "stashapp.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}/Videos";
      };

      replicas = 1;
      enableGPU = false; # Don't request exclusive GPU resource
      sharedGPU = true; # Enable shared GPU mode (mount /dev/dri for time-sharing)
    };

    # ../applications/whisparr/default.nix
    whisparr = {
      database = {
        enable = true;
        host = "postgresql.postgresql";
        port = 5432;
        name = "whisparr";
        username = "whisparr";
        password = secrets.postgresql.userPassword;
      };

      enable = false;

      ingress = {
        domain = "whisparr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      replicas = 1;
    };
  };
}
