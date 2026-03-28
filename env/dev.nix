{ pkgs, self, ... }:
let
  secrets = self.lib.loadSecrets { inherit pkgs; };
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
  # FIXME: naughty config
  ageRecipients = "age1n372e8dgautnjhecllf7uvvldw9g6vyx3kggj0kyduz5jr2upvysue242c";

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

    airflow = {
      enable = false;

      ingress = {
        inherit clusterIssuer;
        domain = "airflow.${base-domain}";
      };
    };

    alice-bitcoin.enable = false;

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

    argocd.enable = true;
    argo-events.enable = false;

    argo-workflows = {
      enable = false;

      ingress = {
        domain = "argo-workflows.${base-domain}";
        ingressClassName = "traefik";
      };
    };

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

    booklore = {
      enable = true;
      hostAffinity = "edgenix";

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

    cloudbeaver = {
      enable = true;
      hostAffinity = "edgenix";

      ingress = {
        domain = "cloudbeaver.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      storageClass = "longhorn";
    };

    dozzle = {
      enable = false;
      hostAffinity = "nasnix";

      ingress = {
        domain = "dozzle.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };
    };

    ersatztv = {
      enable = false;
      # logLevel = "Debug";
      hostAffinity = "edgenix";

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

      enableGPU = true;
      vaapiRenderDevice = "renderD129";
    };

    gluetun = {
      controlServer = { inherit (secrets.gluetun) password username; };
      enable = true;
      hostAffinity = "edgenix";
      mullvadAccountNumber = secrets.mullvad.id;
      storageClassName = "longhorn";
    };

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

    grafana = {
      adminPassword = secrets.grafana.password or "";
      enable = true;
      hostAffinity = "edgenix";

      ingress = {
        clusterIssuer = "tailscale";
        domain = "grafana.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    prometheus = {
      enable = true;
      hostAffinity = "edgenix";

      # Additional scrape configs for monitoring other hosts
      # Example format (uncomment and modify as needed):
      additionalScrapeConfigs = [
        # {
        #   job_name = "node-exporter-remote";
        #   static_configs = [
        #     {
        #       targets = [
        #         "host1.${tail-domain}:9100"
        #         "host2.${tail-domain}:9100"
        #       ];
        #       labels = {
        #         instance = "remote-host";
        #       };
        #     }
        #   ];
        # }
      ];

      alertmanager = {
        enabled = true;
      };
    };

    harbor = {
      domain = "harbor.${base-domain}";
      enable = false;
    };

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

    homarr = {
      enable = true;
      hostAffinity = "edgenix";

      ingress = {
        domain = "homarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      secretEncryptionKey = secrets.homarr.secretEncryptionKey;
      storageClassName = "longhorn";
    };

    home-assistant = {
      enable = true;
      # hostAffinity = "edgenix";

      # https://github.com/AiDot-Development-Team/hass-AiDot
      installAidot.enable = true;

      ingress = {
        domain = "home-assistant.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
        tls.enable = true;
      };

      storageClassName = "longhorn";
    };

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

    kite = {
      inherit (secrets.kite) encryptKey jwtSecret;
      enable = true;
      hostAffinity = "edgenix";
      storageClassName = "longhorn";

      ingress = {
        domain = "kite.${tail-domain}";
        clusterIssuer = "tailscale";
        ingressClassName = "tailscale";
        tls.enable = true;
      };
    };

    kyverno.enable = false;

    lidarr = {
      enable = false;

      ingress = {
        domain = "lidarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      vpn = {
        enable = false;
        sharedGluetunService = "gluetun.gluetun";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";

        slskdDownloads = {
          enable = true;
          path = "${nas-base}/slskd_downloads";
        };
      };

      database = {
        enable = true;
        host = "postgresql.postgresql";
        port = 5432;
        name = "lidarr";
        username = "lidarr";
        password = secrets.postgresql.userPassword;
      };

      hostAffinity = "edgenix";

      replicas = 1;
      storageClassName = "longhorn";
    };

    slskd = {
      enable = false;

      ingress = {
        domain = "slskd.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      hostAffinity = "edgenix";

      webAuth = {
        username = (secrets.slskd or { }).username or "";
        password = (secrets.slskd or { }).password or "";
      };

      apiKey = (secrets.slskd or { }).apiKey or "";

      vpn = {
        enable = true;
        sharedGluetunService = "gluetun.gluetun";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}/slskd_downloads";
      };

      shares = {
        enable = true;
        server = nas-host;
        path = "${nas-base}/Music";
      };

      replicas = 1;
      storageClassName = "longhorn";
      useProbes = false;
    };

    soularr = {
      enable = false;
      hostAffinity = "edgenix";

      lidarr = {
        host = "lidarr.lidarr";
        port = 8686;
        downloadDir = "/downloads/slskd_downloads";
        apiKey = (secrets.soularr or { }).lidarrApiKey or "";
      };

      slskd = {
        host = "slskd.slskd";
        port = 5030;
        apiKey = (secrets.slskd or { }).apiKey or "";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}/slskd_downloads";
      };

      scriptInterval = 300;
      storageClassName = "longhorn";
    };

    lldap.enable = false;

    longhorn = {
      enable = true;

      ingress = {
        domain = "longhorn.${tail-domain}";
        ingressClassName = "tailscale";
        tls.enable = true;
      };
    };

    metallb = {
      enable = true;
      l2.addresses = [ "192.168.0.240-192.168.0.250" ];
    };

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
      hostAffinity = "edgenix";
      storageClass = "longhorn";

      extraDatabases = [
        {
          name = "booklore";
          username = "booklore";
          password = secrets.booklore.database.password;
        }
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

    memos = {
      enable = true;
      hostAffinity = "edgenix";

      ingress = {
        domain = "memos.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    metabase = {
      enable = false;

      ingress = {
        domain = "metabase.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

    mindsdb = {
      enable = false;

      ingress = {
        domain = "mindsdb.${tail-domain}";
        ingressClassName = "tailscale";
      };
    };

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

    mssql.enable = false;

    n8n = {
      enable = true;

      hostAffinity = "nasnix";

      encryptionKey = (secrets.n8n or { }).encryptionKey or "";

      ingress = {
        domain = "n8n.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };
    };

    nocodb =
      let
        storage-backend = "rustfs";
      in
      {
        allowLocalExternalDatabases = true;
        auth.jwtSecret = (secrets.nocodb or { }).jwtSecret or "";
        enable = true;

        ingress = {
          domain = "nocodb.${tail-domain}";
          ingressClassName = "tailscale";
          clusterIssuer = "tailscale";
        };

        database = {
          host = "postgresql.postgresql";
          port = 5432;
          name = "nocodb";
          username = "nocodb";
          password = (secrets.nocodb.postgresql or { }).password or secrets.postgresql.userPassword;
        };

        redis = {
          host = "redis.redis";
          port = 6379;
          password = secrets.redis.password;
        };

        storage =
          if storage-backend == "rustfs" then
            {
              enable = true;
              backend = "rustfs";
              bucketName = (secrets.rustfs or { }).bucketName or "nocodb";
              endpoint = "http://rustfs.rustfs:9000";
              region = (secrets.rustfs or { }).region or "us-east-1";
              accessKey = (secrets.rustfs or { }).accessKey or "";
              secretKey = (secrets.rustfs or { }).secretKey or "";
            }
          else
            {
              enable = true;
              backend = "minio";
              bucketName = (secrets.nocodb.minio or { }).bucketName or "nocodb";
              endpoint = "http://minio.minio:9000";
              region = (secrets.nocodb.minio or { }).region or "us-east-1";
              accessKey = (secrets.nocodb.minio or { }).rootUser or "";
              secretKey = (secrets.nocodb.minio or { }).rootPassword or "";
            };

        publicUrl = "https://nocodb.${tail-domain}";
      };

    pihole = {
      auth = { inherit (secrets.pihole) email password; };
      enable = true;
      hostAffinity = "nasnix";

      ingress = {
        domain = "pihole.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
        tls.enable = true;
      };

      serviceDnsLoadBalancerIP = "192.168.0.242";
      storageClass = "longhorn";
    };

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
      hostAffinity = "edgenix";
      storageClass = "longhorn";

      extraDatabases =
        arrDatabases [
          { name = "prowlarr"; }
          { name = "sonarr"; }
          { name = "radarr"; }
          { name = "lidarr"; }
          { name = "whisparr"; }
        ]
        ++ [
          {
            name = "nocodb";
            username = "nocodb";
            password = secrets.postgresql.userPassword;
          }
        ];
    };

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
      hostAffinity = "edgenix";

      ingress = {
        domain = "prowlarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      replicas = 0;
    };

    qbittorrent = {
      enable = false;
      hostAffinity = "nasnix";

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

    radarr = {
      database = {
        enable = true;
        host = "postgresql.postgresql";
        port = 5432;
        name = "radarr";
        username = "radarr";
        password = secrets.postgresql.userPassword;
      };

      enable = true;
      hostAffinity = "edgenix";
      image = "linuxserver/radarr:6.0.4.10291-ls295";

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
      vpn.enable = false;
    };

    redis = {
      enable = true;
      hostAffinity = "edgenix";
      password = secrets.redis.password;
    };

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

    rustfs = {
      accessKey = (secrets.rustfs or { }).accessKey or "";
      enable = true;
      hostAffinity = "nasnix";

      ingress = {
        domain = "rustfs.${tail-domain}";
        api-domain = "api-rustfs.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
        tls.enable = true;
      };

      mode = "standalone";
      secretKey = (secrets.rustfs or { }).secretKey or "";
      storageClassName = "longhorn";
    };

    satisfactory.enable = false;

    sabnzbd = {
      enable = true;
      hostAffinity = "edgenix";

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
      useProbes = false;
    };

    sealed-secrets.enable = true;

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
      image = "linuxserver/sonarr:version-4.0.17.2952";
      hostAffinity = "edgenix";

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
      vpn.enable = false;
    };

    tunarr = {
      enable = true;
      enableGPU = true;
      hostAffinity = "edgenix";
      resetDatabase = false;

      ingress = {
        domain = "tunarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = false;
        server = nas-host;
        path = "${nas-base}";

        config = {
          enable = false;
          path = "${nas-base}/tunarr";
        };
      };

      replicas = 1;
      storageClassName = "local-path";
      vaapiRenderDevice = "renderD129";
    };

    tube-archivist = {
      auth = {
        inherit (secrets.tube-archivist.auth) username password;
      };

      elasticsearch.elasticPassword = secrets.tube-archivist.auth.password;
      enable = false;
      hostAffinity = "edgenix";

      ingress = {
        domain = "tube-archivist.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      redis = {
        host = "redis.redis";
        port = 6379;
        password = secrets.redis.password;
      };
      storageClassName = "longhorn";
      replicas = 1;
    };

    sops.enable = true;

    windmill = {
      enable = true;
      hostAffinity = "edgenix";

      ingress = {
        domain = "windmill.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      database = {
        host = "postgresql.postgresql";
        port = 5432;
        name = "windmill";
        username = secrets.windmill.database.username;
        password = secrets.windmill.database.password;
      };

      storageClassName = "longhorn";
      replicas = 1;
    };

    spark = {
      enable = false;

      ingress = {
        domain = "spark.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };
    };

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

    tdarr = {
      enable = true;
      healthcheckcpuWorkers = 0;
      healthcheckgpuWorkers = 1;
      hostAffinity = "edgenix";

      ingress = {
        domain = "tdarr.${tail-domain}";
        ingressClassName = "tailscale";
        clusterIssuer = "tailscale";
      };

      nfs = {
        enable = true;
        server = nas-host;
        path = "${nas-base}";
      };

      puid = 1000;
      pgid = 1000;

      replicas = 1;
      storageClassName = "longhorn";
      useProbes = false;
      vpn.enable = false;
      enableGPU = true;
      enableNvidiaGPU = false;
      # Edgenix has two cards; WX 3200 (VAAPI) is renderD129. Mount it as renderD128 so Tdarr's hardcoded path works.
      vaapiRenderDevice = "renderD129";
      libvaDriverName = "radeonsi";
      transcodegpuWorkers = 1;
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
      enableGPU = true;
    };

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
