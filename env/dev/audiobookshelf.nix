{ secrets, ... }:
{
  services.audiobookshelf = {
    enable = true;
    apiKey = secrets.audiobookshelf.key;
    # hostAffinity = "edgenix";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;
    monitoring.autokuma.enable = true;
    homepage.group = "Media";

    nfsTarget = "nas";
    nfsSubPath = "Audiobooks";
    nfs.enable = true;
  };
}
