{ secrets, config, ... }:
{
  services.metabase = {
    enable = true;

    ingressProvider = "traefik-lan";

    # Flip these on by populating metabase.admin.password in secrets.enc.yaml (see
    # `nur secrets edit`) -- until then the register-connections job is skipped
    # entirely (see applications/metabase.nix).
    admin = {
      email = (secrets.metabase or { }).admin.email or "admin@metabase.local";
      password = (secrets.metabase or { }).admin.password or "";
    };

    # One entry per Postgres database to expose in Metabase, sourced the same way
    # as superset's reportingConnections (env/dev/superset.nix) -- just a single
    # database here as a starting example; extend to
    # `map (db: { inherit (db) name username password; inherit (config.databaseProviders.postgresql) host port; }) config.services.postgresql.extraDatabases`
    # once this is proven out, to register all of them automatically.
    reportingConnections = [
      {
        inherit (config.databaseProviders.postgresql) host port;
        name = "immich";
        username = "immich";
        password = secrets.postgresql.userPassword;
      }
    ];
  };
}
