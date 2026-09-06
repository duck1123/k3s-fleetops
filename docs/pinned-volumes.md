# Pinned Volumes

Apps in this repo go through `enable = false` → `enable = true` cycles a lot (an app gets disabled while its dependencies are worked out, or just because it's not needed right now). ArgoCD's `finalizer = "foreground"` + `Prune` means disabling an app deletes its `PersistentVolumeClaim` outright, not just the Deployment. A fresh dynamic PVC on re-enable has no way to find the volume the old one pointed at -- the StorageClass just hands back a new, empty one.

The cluster's `longhorn` StorageClass already sets `reclaimPolicy: Retain`, so the *actual* Longhorn volume and its data survive a PVC deletion regardless -- it just becomes orphaned, with nothing in Kubernetes pointing at it anymore. "Pinning" a volume means writing a `PersistentVolume` by hand with a fixed, known `csi.volumeHandle` (the Longhorn volume's real identity) and binding a PVC to it by name, instead of letting a StorageClass provision on demand. The PV/PVC objects themselves are still free to be deleted and recreated by ArgoCD every enable/disable cycle -- only `volumeHandle` has to stay the same, and it always resolves back to the same backing data.

This is specifically for **small, precious, hand-managed volumes** (an app's config/database/settings) -- not for bulk media libraries, which this repo instead handles via NFS mounts (`uses-nfs`) or plain dynamic Longhorn PVCs that are fine to lose and recreate.

## Using it: `pinnedVolumes` on `mkArgoApp`

Every `mkArgoApp` call can take a `pinnedVolumes` parameter: a function of `cfg` returning an attrset keyed by a short logical volume name, each value being the arg-set for [`self.lib.mkPinnedVolume`](../modules/lib/mkPinnedVolume.nix) minus `pvcName` (that part is derived automatically):

```nix
self.lib.mkArgoApp { inherit config lib self pkgs; } {
  name = "myapp";

  pinnedVolumes = cfg: {
    appdata = {
      volumeHandle = "pvc-<uuid>"; # captured from the live cluster -- see below
      size = "5Gi";
    };
  };

  extraResources = cfg: {
    deployments.myapp.spec.template.spec = {
      containers = [{
        name = "myapp";
        volumeMounts = [
          { name = "appdata"; mountPath = "/config"; }
        ];
      }];
      volumes = [
        cfg.pinnedVolumes.appdata.volume
      ];
    };
  };
};
```

This does three things automatically:
- Generates the `PersistentVolumeClaim`/`PersistentVolume` pair (named `"${name}-${name}-appdata"` by default) and merges them into the app's resources -- no need to spread anything into `extraResources` yourself.
- Exposes `cfg.pinnedVolumes.appdata.pvcName` (the generated PVC's k8s name) and `cfg.pinnedVolumes.appdata.volume` (a ready `{ name; persistentVolumeClaim.claimName; }` entry) so `extraResources`/`extraAppConfig` can reference it without hand-typing the naming convention.
- Supports multiple entries per app -- see `applications/paperless-ngx.nix` (`data`/`media`/`export`/`consume`) or `applications/tdarr.nix` for apps with more than one pinned volume.

An app can freely mix pinned and dynamic/NFS volumes -- the common pattern across `*arr` apps is a small pinned `config` volume alongside a large dynamic or NFS-backed `downloads`/`media` volume that's fine to lose. See `applications/sonarr.nix` or `applications/lidarr.nix`.

### Overriding the generated name

Pass an explicit `pvcName` (and/or `pvName`) inside a volume's arg-set when the default `"${name}-${name}-<key>"` convention doesn't fit -- e.g. a Helm chart with an `existingClaim`-style value that expects a specific literal string. `applications/pihole.nix` needs this: its chart config already says `existingClaim = "pihole"`, so its `pinnedVolumes.data` sets `pvcName = "pihole";` to match.

## Capturing a `volumeHandle`

`mkPinnedVolume` (and `pinnedVolumes`) can't look up a `volumeHandle` themselves -- it has to be captured once from the live cluster before first use. Two cases:

**An app that's already running on a dynamically-provisioned PVC**, and you want to pin it before its next disable/re-enable cycle:

```sh
# Find the PV a PVC is currently bound to
kubectl get pvc <pvc-name> -n <namespace> -o jsonpath='{.spec.volumeName}'

# Read that PV's actual Longhorn volume identity
kubectl get pv <pv-name-from-above> -o jsonpath='{.spec.csi.volumeHandle}'
```

**A brand-new app with no PVC yet**: let it deploy once with an ordinary dynamic PVC (don't set `pinnedVolumes` yet), confirm it's healthy, then run the two commands above against the PVC it created, and only then add `pinnedVolumes` pointing at that handle. You can't pin a volume that doesn't exist yet -- there has to be a bootstrapping deploy first.

Either way, paste the resulting `pvc-<uuid>` string in as a literal -- don't try to compute or look it up from an option, since nothing in this repo's Nix evaluation has live cluster access.

## Gotchas

- **Resizing**: `mkPinnedVolume` defaults `storageClassName = ""` (fully static, no provisioner involvement -- the safest default). Longhorn's admission webhook refuses to resize any PVC whose `storageClassName` is `""` ("only dynamically provisioned pvc can be resized" -- [longhorn/longhorn#6446](https://github.com/longhorn/longhorn/issues/6446)). If a pinned volume might need `kubectl patch volumes.longhorn.io ... spec.size` resizing later, pass `storageClassName = "longhorn"` instead -- but note `storageClassName` is immutable on an existing PVC, so switching it after the fact means deleting and recreating the PVC (the PV/`volumeHandle` binding is unaffected either way).
- **The PV object name is cosmetic.** Renaming a pinned volume's PV (e.g. by changing which `pinnedVolumes` key it's under) doesn't touch the underlying data -- only `volumeHandle` does. ArgoCD deleting an old-named PV and creating a new-named one pointed at the same `volumeHandle` is a harmless rebind, not data loss (`persistentVolumeReclaimPolicy: Retain` guarantees the old PV's deletion never touches the backing volume).
- **`sync-options: Replace=true`** on both the PVC and PV (already set by `mkPinnedVolume`) is required -- without it, ArgoCD's normal apply semantics choke on `volumeName`/`storageClassName` being effectively-immutable fields if the object already exists with different values.
