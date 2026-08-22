{ ... }:
{
  services.audiobookshelf = {
    enable = true;
    # hostAffinity = "edgenix";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    nfsTarget = "nas";
    nfsSubPath = "Audiobooks";
    nfs.enable = true;
  };
}
