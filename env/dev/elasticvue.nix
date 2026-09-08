{ secrets, ... }:
{
  services.elasticvue = {
    enable = true;

    ingressProvider = "traefik-lan";

    clusters = [
      {
        name = "Ditto Relay (OpenSearch)";
        uri = "http://ditto-relay-opensearch.ditto-relay:9200";
      }
      {
        name = "Tube Archivist (Elasticsearch)";
        uri = "http://tube-archivist-es.tube-archivist:9200";
        username = "elastic";
        password = secrets.tube-archivist.auth.password;
      }
    ];

    homepage.group = "Database";
  };
}
