{ password ? "foo", ...}: {
  Chart = {
    Name = "jupyterhub";
    Version = "8.1.5";
  };

  cull = {
    enabled = true;
    users = false;
    removeNamedServers = false;
    timeout = 3600;
    every = 600;
    concurrency = 10;
    maxAge = 0;
  };

  hub = {
    activeServerLimit = null;
    allowNamedServers = false;
    concurrentSpawnLimit = 64;

    config.JupyterHub = {
      admin_access = true;
      Authenticator.admin_users = [ "admin" ];
      authenticator_class = "dummy";
      DummyAuthenticator.password = password;
    };

    consecutiveFailureLimit = 5;
    cookieSecret = null;

    db = {
      type = "postgres";
      url =
        "postgresql://bn_jupyterhub@jupyterhub-postgresql:5432/bitnami_jupyterhub";
    };

    namedServerLimitPerUser = null;
    redirectToServer = null;
    services = { };
    shutdownOnLogout = null;
  };

  Release = {
    Name = "jupyterhub";
    Namespace = "jupyterhub";
    Service = "Helm";
  };

  singleuser = {
    automountServiceAccountToken = false;
    cloudMetadata.blockWithIptables = false;

    cpu = {
      limit = 0.75;
      guarantee = 0.5;
    };

    containerSecurityContext = {
      allowPrivilegeEscalation = false;
      capabilities.drop = [ "ALL" ];
      privileged = false;
      readOnlyRootFilesystem = true;
      runAsGroup = 1001;
      runAsNonRoot = true;
      runAsUser = 1001;
      seccompProfile.type = "RuntimeDefault";
      seLinuxOptions = { };
    };

    cmd = "jupyterhub-singleuser";
    defaultUrl = null;
    events = true;
    extraAnnotations = null;

    extraLabels = {
      "app.kubernetes.io/component" = "singleuser";
      "app.kubernetes.io/instance" = "jupyterhub";
      "app.kubernetes.io/managed-by" = "Helm";
      "app.kubernetes.io/name" = "jupyterhub";
      "app.kubernetes.io/version" = "4.1.6";
      "hub.jupyter.org/network-access-hub" = "true";
      "helm.sh/chart" = "jupyterhub-8.1.5";
    };

    fsGid = 1001;

    image = {
      name = "docker.io/bitnami/jupyter-base-notebook";
      tag = "4.1.6-debian-12-r27";
      digest = null;
      pullPolicy = "IfNotPresent";
      pullSecrets = null;
    };

    memory = {
      limit = "768M";
      guarantee = "512M";
    };

    networkTools.image = {
      digest = null;
      name = "docker.io/bitnami/os-shell";
      pullPolicy = "IfNotPresent";
      pullSecrets = null;
      tag = "12-debian-12-r40";
    };

    podNameTemplate = "jupyterhub-jupyter-{username}";

    podSecurityContext = {
      fsGroup = 1001;
      fsGroupChangePolicy = "Always";
      supplementalGroups = [ ];
      sysctls = [ ];
    };

    serviceAccountName = "jupyterhub-singleuser";

    storage = {
      capacity = "10Gi";

      dynamic = {
        pvcNameTemplate = "jupyterhub-claim-{username}{servername}";
        volumeNameTemplate = "jupyterhub-volume-{username}{servername}";
        storageAccessModes = [ "ReadWriteOnce" ];
      };

      extraLabels = {
        "app.kubernetes.io/component" = "singleuser";
        "app.kubernetes.io/instance" = "jupyterhub";
        "app.kubernetes.io/managed-by" = "Helm";
        "app.kubernetes.io/name" = "jupyterhub";
        "app.kubernetes.io/version" = "4.1.6";
        "helm.sh/chart" = "jupyterhub-8.1.5";
      };

      extraVolumes = [{
        name = "empty-dir";
        emptyDir = { };
      }];

      extraVolumeMounts = [{
        name = "empty-dir";
        mountPath = "/tmp";
        subPath = "tmp-dir";
      }];

      homeMountPath = "/opt/bitnami/jupyterhub-singleuser";
      type = "dynamic";
    };

    startTimeout = 300;
    uid = 1001;
  };
}
