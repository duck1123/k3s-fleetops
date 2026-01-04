{ charts, config, lib, ... }:
let
  crossplane-cfg = config.services.crossplane;
  cfg = crossplane-cfg.providers.digital-ocean;
  namespace = crossplane-cfg.namespace;
in with lib; {
  options.services.crossplane.providers.digital-ocean.enable =
    mkEnableOption "Enable Digital Ocean Provider";

  config = mkIf cfg.enable {
    applications.crossplane-providers-digital-ocean = {
      inherit namespace;
      finalizer = "foreground";
      resources = {
        # droplets.test-droplet = {
        #   annotations."crossplane.io/external-name" = "crossplane-droplet";

        #   spec = {
        #     forProvider = {
        #       region = "nyc1";
        #       size = "s-1vcpu-1gb";
        #       image = "ubuntu-20-04-x64";
        #       userData = ''
        #         #!/bin/bash
        #         apt-get -y update
        #         apt-get -y install nginx
        #         export HOSTNAME=$(curl -s http://169.254.169.254/metadata/v1/hostname)
        #         export PUBLIC_IPV4=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
        #         echo Droplet: $HOSTNAME, IP Address: $PUBLIC_IPV4 > /var/www/html/index.html
        #       '';
        #     };
        #     providerConfigRef.name = "do-provider";
        #   };
        # };

        providers.provider-upjet-digitalocean = {
          metadata = { inherit namespace; };
          spec.package =
            "xpkg.upbound.io/digitalocean/provider-digitalocean:v0.2.0";
        };

        # providerConfigs.do-provider.spec.credentials = {
        #   source = "secret";
        #   secretRef = {
        #     namespace = "crossplane-system";
        #     name = "provider-do-secret";
        #     key = "token";
        #   };
        # };

        sealedSecrets.provider-do-secret = {
          metadata.annotations."sealedsecrets.bitnami.com/cluster-wide" =
            "true";

          spec = {
            encryptedData.token =
              "AgBd8gV9ximtsET68/KNHfsxdf1Otsb8je551H0MoMrUzfn8v9MtwIGOzniPHuqCSK4kcbfPHKugrEFusxr/gDvYkIy4zmxm9t4e39FujJdQK3eSujDzaHig9rk9/uf8eonp24ziW18AHA5doGLMBTEWlRMut/qMg6W+TyQ7/FNx6OU02VDBym/AygrHoIuWSi06TY8BHAdYFrDIDQcXvJJ1urVSkORXApmU586/ypC38JTwP7RuPxlYIrRCJ1Mk4FTao6wKril65ZUgU8OkWaDhGgLnqbW9SLRQipUf03QIb6ZFRPvFiaMoVaAzlY/Awt9IJGcB7dYfYZErcd7mvwMs+YEEeuYvEJbs/7XA7VVFjTwgYSFuxHMXg+gWUurfK31SodY6XGEUCnLNwgBgYMyYLqqUxKmif5+tEraH2ufk/yIXihboqBE5u41CqERYgZJfBBvdQCDOjs4k7WhXF2F2wkA7zMwb+UmznlM0vC3TF8/LR60qu5ngeGTXoEjfLGKeQp84t5vFdf/XRRzYf8UffYBlwpLU3aOsMcAA3MygCrKahtgTAfyRCy1sUO+V007z3BooVnc7byA03ZQeeOXTZTRphFfWyncgqGR/aRiQp2mnl73TfeRsEu1tJ6NEkeb/AMUrce9pzcmBPr1BV0EbLwzQj2wMMm2y9ozp2V63GMZM8BmyQDqQ9xxbpmWzAEgwR+veQfpjctsE4v9JSaBLV994awgwYfCjz4uFJyVygKCAsrhHytbvOv5Hb2l6wa1A+Q76mdVtU90nnuwc02O17S15/M5S1Q==";
            template.metadata = {
              annotations."sealedsecrets.bitnami.com/cluster-wide" = "true";
              creationTimestamp = null;
              name = "provider-do-secret";
              namespace = "crossplane-system";
            };
          };
        };
      };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];
    };
  };
}
