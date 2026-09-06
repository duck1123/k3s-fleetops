{ config, secrets, ... }:
{
  services.bookorbit = {
    enable = true;

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;
    homepage.group = "Media";

    databaseTarget = "postgresql";

    # Same NAS library booklore/komga already point at.
    nfsTarget = "nas";
    nfsSubPath = "Books";
    nfs.enable = true;
    # Second export, mounted at /books/Audiobooks -- same NAS folder
    # audiobookshelf already points at.
    nfs.audiobooksPath = "${config.devDefaults.nasBase}/Audiobooks";

    jwtSecret = (secrets.bookorbit or { }).jwtSecret or "";
    setupBootstrapToken = (secrets.bookorbit or { }).setupBootstrapToken or "";

    # No volumeOverrides yet -- this is a brand-new app with no PVC to pin.
    # Once it's up, capture the "data" PVC's volumeHandle and pin it here --
    # see docs/pinned-volumes.md.
  };
}
