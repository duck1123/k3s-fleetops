{ ... }:
{
  services.memos = {
    enable = true;
    # hostAffinity = "edgenix";

    databaseTarget = "postgresql";
    database.username = "postgres";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    monitoring.autokuma.enable = true;
  };
}
