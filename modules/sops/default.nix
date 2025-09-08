{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "sops";

  # https://artifacthub.io/packages/helm/sops-secrets-operator/sops-secrets-operator
  chart = lib.helm.downloadHelmChart {
    repo = "https://isindir.github.io/sops-secrets-operator/";
    chart = "sops-secrets-operator";
    version = "0.21.0";
    chartHash = "sha256-SmSp9oo8ue9DuRQSHevJSrGVVB5xmmlook53Y8AfUZY=";
  };

  defaultValues = cfg: {
    extraEnv = [{
      name = "SOPS_AGE_KEY_FILE";
      value = "/etc/sops-age-key-file/key";
    }];
    secretsAsFiles = [{
      mountPath = "/etc/sops-age-key-file";
      name = "sops-age-key-file";
      secretName = "sops-age-key-file";
    }];
  };

  extraConfig = cfg: { nixidy.resourceImports = [ ./generated.nix ]; };

  extraResources = cfg: {
    sealedSecrets = {
      sops-age-key-file-sealed-secret = {
        spec = {
          encryptedData = {
            key =
              "AgC7egoLjUOvqAa9OdLfC0OPaqdZaGZDuv9YGvu1LrjRfBQFoZtjtRCpRu3VBwii9KzklL38iWJBTrfZW48Fb6SBtzV1dZd5dBDuAR/qA6AE8RwmYc91rrIB0Z6KJ20Qn3wwQczxiEDYmEqkV5t+nrMlsBY3Mkm458UvuG3a2uKOsjYNASp07uJjOEQB+HNEvdBP2mKC68X2tAFziMStiyUGm4D4zfVshg+JN8gjCONjW9urwdWxHDxsCR0MEEspr+szzu3Y5gLfLPCpIgegP7F7C2EIs7+pRtVEULNlwDaRho52CI4ck9gelLpKbAASYHs484D6pVxBjrlvl8EoylVgzpZjOwl2k4PyCwQJRDB5PJj2LObfTYFSs0mny7TSPETA1dF0jtuO0O2mXvIBZ8qBRm6Jabrbap62S6YwcRhjItYS6BWlUdVyXkz3aHUlNM4/QUxgJ4d6Id03VaglIoPHSAuK/tvahjnpJSGAT+FLZ+2raUAzFUgxCugPrYOhsAulyzRA7cExDRxY0QA2nn3gmTzbC0t3eL573XbKGfEYg4Dt3OwXJMaZL8ocmmUXFjIN9lry4lM1NNxS/jkGJwQcMJuG/JmKafTF+QGwypYwc0GEOMJRVIE+BUq/h/2ByEATMQMj3Tpp0udBdRK2YyYIlwu7+riqL/Y9vC19gOVeIMSer1XzBcQb6S9bN7kOh/Odv7JA0QLfyRgvYJlS3zzQ4x/oKJlirtPthcUjt9Ghb3RbHfwTysjcR1cYX423YHnDaDqz2IQ0dmiRUxFZnUZ7dIfai04d+JNVgQ==";
          };

          template.metadata = {
            name = "sops-age-key-file";
            namespace = "sops";
          };
        };
      };
    };
  };
}
