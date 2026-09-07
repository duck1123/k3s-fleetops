{ secrets, ... }:
{
  services.mariadb = {
    auth = {
      inherit (secrets.mariadb)
        database
        password
        rootPassword
        username
        ;
    };

    enable = true;
    hostAffinity = "edgenix";
    storageClassName = "longhorn";

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

    # `data` is deliberately unpinned here during the bitnami->groundhog2k
    # chart migration: the old pinned volume (pvc-7ef8145c-...) is laid out
    # for bitnami's /bitnami/mariadb mount, which doesn't match this chart's
    # stock /var/lib/mysql image -- a fresh dynamic volume + dump/restore is
    # the safe path (see IMAGE-VERSIONS.md). Re-pin once the new volume is
    # confirmed healthy, per docs/pinned-volumes.md.
    #
    # Captured via `kubectl get pv <name> -o jsonpath='{.spec.csi.volumeHandle}'`
    # -- see docs/pinned-volumes.md. Specific to this cluster.
    volumeOverrides = {
      backups.volumeHandle = "pvc-f42c562c-5275-4ae2-999c-94eab513bcd9";
    };
  };
}
