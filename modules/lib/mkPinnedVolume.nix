{ ... }:
{
  # mkPinnedVolume
  #
  # Returns a { persistentVolumeClaims; persistentVolumes; } fragment binding
  # `pvcName` to a fixed-name PersistentVolume whose csi.volumeHandle is an
  # *existing* Longhorn volume's real identity, rather than letting the
  # StorageClass dynamically provision a fresh (empty) one.
  #
  # Why: this repo's apps go through `enable = false` -> `enable = true`
  # cycles via ArgoCD's prune + foreground-finalizer cascade, which deletes
  # PVCs (and any hand-authored PVs) outright on disable. The underlying
  # Longhorn volume survives regardless (the cluster's "longhorn"
  # StorageClass already sets reclaimPolicy: Retain), but a fresh dynamic
  # PVC on re-enable has no way to find that orphaned volume again -- it
  # just gets a new empty one. Pinning the PVC to a PV with a known,
  # unchanging volumeHandle fixes that: the PV/PVC objects are free to be
  # deleted and recreated every cycle, but volumeHandle always points at the
  # same backing data.
  #
  # `volumeHandle` must be captured once from the live cluster (`kubectl get
  # pv <name> -o jsonpath='{.spec.csi.volumeHandle}'`) before first use --
  # this function has no way to look it up itself.
  #
  # Both objects carry `Replace=true,Force=true` (not just `Replace=true`):
  # switching an already-bound PVC from a dynamic PV to this one changes
  # `volumeName`/`storageClassName`, which Kubernetes treats as immutable
  # once bound -- a plain `kubectl replace` (what `Replace=true` alone gets
  # you) is rejected with "spec is immutable after creation", and ArgoCD
  # just retries the same failing replace forever rather than falling back
  # to a delete+recreate. `Force=true` is what actually makes ArgoCD do that
  # delete+recreate on such a conflict. This only ever lands on the PVC/PV a
  # pinned volume generates -- unpinned/dynamic volumes get no sync-options
  # annotation at all, and it can't leak onto any other resource in the app.
  #
  # `storageClassName` defaults to "" (fully static, no provisioner
  # involvement -- the safest default, and what every currently-pinned
  # volume in this repo uses). Longhorn's admission webhook refuses to
  # expand any volume whose PVC has storageClassName "" ("only dynamically
  # provisioned pvc can be resized" -- see longhorn/longhorn#6446), even
  # though `volumeName` still binds statically regardless of
  # storageClassName. Pass storageClassName = "longhorn" for a volume that
  # may need `kubectl patch volumes.longhorn.io ... spec.size` resizing
  # later -- but note this requires a delete+recreate of the PVC if it was
  # already provisioned with the "" default, since storageClassName is
  # immutable on an existing PVC.
  flake.lib.mkPinnedVolume =
    {
      pvcName,
      volumeHandle,
      size,
      pvName ? "${pvcName}-pv",
      accessModes ? [ "ReadWriteOnce" ],
      volumeAttributes ? { },
      storageClassName ? "",
    }:
    {
      persistentVolumeClaims.${pvcName} = {
        metadata.annotations."argocd.argoproj.io/sync-options" = "Replace=true,Force=true";
        spec = {
          inherit accessModes storageClassName;
          resources.requests.storage = size;
          volumeName = pvName;
        };
      };

      persistentVolumes.${pvName} = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = pvName;
          annotations."argocd.argoproj.io/sync-options" = "Replace=true,Force=true";
        };
        spec = {
          capacity.storage = size;
          inherit accessModes storageClassName;
          persistentVolumeReclaimPolicy = "Retain";
          csi = {
            driver = "driver.longhorn.io";
            fsType = "ext4";
            inherit volumeHandle;
            volumeAttributes = {
              numberOfReplicas = "1";
              staleReplicaTimeout = "30";
              fromBackup = "";
              fsType = "ext4";
              dataLocality = "disabled";
              unmapMarkSnapChainRemoved = "ignored";
              disableRevisionCounter = "true";
              dataEngine = "v1";
            }
            // volumeAttributes;
          };
        };
      };
    };
}
