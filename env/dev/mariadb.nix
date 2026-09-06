{ secrets, ... }:
{
  services.mariadb = {
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

    # Captured via `kubectl get pv <name> -o jsonpath='{.spec.csi.volumeHandle}'`
    # -- see docs/pinned-volumes.md. Specific to this cluster.
    volumeOverrides = {
      data.volumeHandle = "pvc-7ef8145c-7770-449b-a78d-81b1df2e17df";
      backups.volumeHandle = "pvc-f42c562c-5275-4ae2-999c-94eab513bcd9";
    };
  };
}
