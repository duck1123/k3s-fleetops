# Pinned Volumes

Apps in this repo go through `enable = false` → `enable = true` cycles a lot (an app gets disabled while its dependencies are worked out, or just because it's not needed right now). ArgoCD's `finalizer = "foreground"` + `Prune` means disabling an app deletes its `PersistentVolumeClaim` outright, not just the Deployment. A fresh dynamic PVC on re-enable has no way to find the volume the old one pointed at -- the StorageClass just hands back a new, empty one.

The cluster's `longhorn` StorageClass already sets `reclaimPolicy: Retain`, so the *actual* Longhorn volume and its data survive a PVC deletion regardless -- it just becomes orphaned, with nothing in Kubernetes pointing at it anymore. "Pinning" a volume means writing a `PersistentVolume` by hand with a fixed, known `csi.volumeHandle` (the Longhorn volume's real identity) and binding a PVC to it by name, instead of letting a StorageClass provision on demand. The PV/PVC objects themselves are still free to be deleted and recreated by ArgoCD every enable/disable cycle -- only `volumeHandle` has to stay the same, and it always resolves back to the same backing data.

This is specifically for **small, precious, hand-managed volumes** (an app's config/database/settings) -- not for bulk media libraries, which this repo instead handles via NFS mounts (`uses-nfs`) or plain dynamic Longhorn PVCs that are fine to lose and recreate.

## A volumeHandle is environment data, not app data

A `volumeHandle` identifies one specific Longhorn volume that exists on *this* cluster. It means nothing anywhere else -- someone standing up a second environment from this same repo would have no such volume, and a literal handle string sitting in `applications/<name>.nix` (which is meant to describe the app in a way that's reusable across environments) would just be wrong for them.

So `mkArgoApp` splits the two apart:

- **`volumes`** (a parameter to `mkArgoApp`, in `applications/<name>.nix`) declares each volume's *shape* -- size, and any naming overrides -- with no handle. Environment-agnostic.
- **`cfg.volumeOverrides.<key>`** (a plain option, set per-environment in e.g. `env/dev/<name>.nix`) is `recursiveUpdate`d on top of that key's shape. `volumeHandle` is the field that pins it, but any field can be overridden this way (`size` most commonly, also `accessModes`, `storageClassName`, `volumeAttributes`, `pvcName`) without touching `applications/<name>.nix`.

A key present in `volumes` but with no `volumeHandle` anywhere (whether via `volumeOverrides` or otherwise) isn't pinned at all -- it's just an ordinary dynamically-provisioned PVC using the app's normal `storageClassName`. That's what a brand-new environment gets automatically, with zero extra config: everything works, it's just not yet guaranteed to survive a disable/re-enable cycle. Once someone captures a real handle for it (see below) and adds one line to that environment's `env/dev/<name>.nix`, the exact same volume becomes pinned on the next `nur switch` -- no change to `applications/<name>.nix` at all.

## Using it

```nix
# applications/myapp.nix
self.lib.mkArgoApp { inherit config lib self pkgs; } {
  name = "myapp";

  # Shape only -- no volumeHandle here.
  volumes = cfg: {
    appdata = { size = "5Gi"; };
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
        cfg.volumes.appdata.volume
      ];
    };
  };
};
```

```nix
# env/dev/myapp.nix -- this environment's own data
{
  services.myapp = {
    enable = true;
    # Captured via `kubectl get pv ... -o jsonpath='{.spec.csi.volumeHandle}'`
    volumeOverrides.appdata.volumeHandle = "pvc-<uuid>";
  };
}
```

This does three things automatically:
- Generates the `PersistentVolumeClaim` (and, once a handle exists, its matching pinned `PersistentVolume`) and merges them into the app's resources -- no need to spread anything into `extraResources` yourself.
- Exposes `cfg.volumes.appdata.pvcName` (the generated PVC's k8s name) and `cfg.volumes.appdata.volume` (a ready `{ name; persistentVolumeClaim.claimName; }` entry) so `extraResources`/`extraAppConfig` can reference it without hand-typing the naming convention.
- Supports multiple entries per app -- see `applications/paperless-ngx.nix` (`data`/`media`/`export`/`consume`) or `applications/tdarr.nix` for apps with more than one volume.

An app can freely mix pinned and dynamic/NFS volumes -- the common pattern across `*arr` apps is a small (potentially pinned) `config` volume alongside a large dynamic or NFS-backed `downloads`/`media` volume that's fine to lose. See `applications/sonarr.nix` or `applications/lidarr.nix`.

### Overriding the generated PVC name

Pass an explicit `pvcName` (and/or `pvName`) inside a volume's arg-set in `volumes` when the default `"${name}-${name}-<key>"` convention doesn't fit -- e.g. a Helm chart with an `existingClaim`-style value that expects a specific literal string. `applications/pihole.nix` needs this: its chart config already says `existingClaim = "pihole"`, so its `volumes.data` sets `pvcName = "pihole";` to match.

## Capturing a `volumeHandle`

Nothing in this repo's Nix evaluation has live cluster access, so a handle has to be captured by hand from `kubectl` before it can go in `volumeOverrides.<key>.volumeHandle`. Two cases:

**An app that's already running on a dynamically-provisioned PVC**, and you want to pin it before its next disable/re-enable cycle:

```sh
# Find the PV a PVC is currently bound to
kubectl get pvc <pvc-name> -n <namespace> -o jsonpath='{.spec.volumeName}'

# Read that PV's actual Longhorn volume identity
kubectl get pv <pv-name-from-above> -o jsonpath='{.spec.csi.volumeHandle}'
```

**A brand-new app with no PVC yet**: just declare it in `volumes` and deploy -- with no matching `volumeOverrides.<key>.volumeHandle`, it comes up as an ordinary dynamic PVC automatically. Once it's healthy, run the two commands above against the PVC it created, then add the resulting handle to that environment's `env/dev/<name>.nix`. You can't pin a volume that doesn't exist yet -- there has to be a bootstrapping deploy first, and until you do the capture-and-add step it just stays an unpinned dynamic volume indefinitely, which is a perfectly fine place to leave anything that doesn't need the guarantee.

Paste the resulting `pvc-<uuid>` string in as a literal in the environment file -- one string, one specific cluster.

## Gotchas

- **Resizing**: `mkPinnedVolume` defaults `storageClassName = ""` for a pinned volume (fully static, no provisioner involvement -- the safest default). Longhorn's admission webhook refuses to resize any PVC whose `storageClassName` is `""` ("only dynamically provisioned pvc can be resized" -- [longhorn/longhorn#6446](https://github.com/longhorn/longhorn/issues/6446)). If a pinned volume might need `kubectl patch volumes.longhorn.io ... spec.size` resizing later, pass `storageClassName = "longhorn"` in its `volumes` entry instead -- but note `storageClassName` is immutable on an existing PVC, so switching it after the fact means deleting and recreating the PVC (the PV/`volumeHandle` binding is unaffected either way).
- **The PV object name is cosmetic.** Renaming a pinned volume's PV (e.g. by changing which `volumes` key it's under) doesn't touch the underlying data -- only `volumeHandle` does. ArgoCD deleting an old-named PV and creating a new-named one pointed at the same `volumeHandle` is a harmless rebind, not data loss (`persistentVolumeReclaimPolicy: Retain` guarantees the old PV's deletion never touches the backing volume).
- **`sync-options: Replace=true`** on both the PVC and PV (already set by `mkPinnedVolume`) is required once a volume is pinned -- without it, ArgoCD's normal apply semantics choke on `volumeName`/`storageClassName` being effectively-immutable fields if the object already exists with different values.
- **Switching a volume from unpinned to pinned changes its PVC's `storageClassName`** (from the app's normal one, e.g. `"longhorn"`, to `""`) -- since that field is immutable on an existing PVC, ArgoCD's `Replace=true` sync option (already set once `mkPinnedVolume` is in play) handles this by deleting and recreating the PVC object, not patching it. That's a real, if brief, unmount/remount of anything actively using the volume -- fine for most of these apps, but worth timing deliberately rather than doing blind on something with active writes in flight.
