{ ... }:
{
  services.keycloak = {
    enable = false;
    ingress = {
      domain = "keycloak.dev.kronkltd.net";
      adminDomain = "keycloak-admin.dev.kronkltd.net";
      clusterIssuer = "letsencrypt-prod";
    };
  };
}
