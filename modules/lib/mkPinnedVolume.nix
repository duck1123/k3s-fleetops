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
  flake.lib.mkPinnedVolume =
    {
      pvcName,
      volumeHandle,
      size,
      pvName ? "${pvcName}-pv",
      accessModes ? [ "ReadWriteOnce" ],
      volumeAttributes ? { },
    }:
    {
      persistentVolumeClaims.${pvcName} = {
        metadata.annotations."argocd.argoproj.io/sync-options" = "Replace=true";
        spec = {
          inherit accessModes;
          resources.requests.storage = size;
          storageClassName = "";
          volumeName = pvName;
        };
      };

      persistentVolumes.${pvName} = {
        apiVersion = "v1";
        kind = "PersistentVolume";
        metadata = {
          name = pvName;
          annotations."argocd.argoproj.io/sync-options" = "Replace=true";
        };
        spec = {
          capacity.storage = size;
          inherit accessModes;
          persistentVolumeReclaimPolicy = "Retain";
          storageClassName = "";
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
