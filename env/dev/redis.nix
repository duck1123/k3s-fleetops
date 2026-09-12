{ secrets, ... }:
{
  services.redis = {
    enable = true;
    hostAffinity = "edgenix";
    password = secrets.redis.password;
    # Scaled to 0 for the pinned-volume cutover -- see docs/pinned-volumes.md.
    # Restore to 1 once the PVC has been deleted and recreated against the pin.
    replicas = 0;
    repairAof = false;

    # Captured via `kubectl get pv <name> -o jsonpath='{.spec.csi.volumeHandle}'`
    # -- see docs/pinned-volumes.md.
    volumeOverrides.data.volumeHandle = "pvc-3432cb71-7a05-4ef4-b957-20ba12c4ab8d";
  };
}
