{ ... }:
{
  services.booklore = {
    enable = false;
    # hostAffinity = "edgenix";

    databaseTarget = "mariadb";

    gid = "0";

    ingressProvider = "traefik-lan";

    nfsTarget = "nas";
    nfsSubPath = "Books";
    nfs.enable = true;

    uid = "0";
  };
}
