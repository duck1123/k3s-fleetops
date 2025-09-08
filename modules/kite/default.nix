{ config, lib, ... }:
with lib;
mkArgoApp { inherit config lib; } {
  name = "kite";

  # https://github.com/zxh326/kite
  chart = helm.downloadHelmChart {
    repo = "https://zxh326.github.io/kite";
    chart = "kite";
    version = "0.5.0";
    chartHash = "sha256-60x7ce2xqNoZqtOZc+pDBNa1Vosbm+ZFxl0i9sHQSzo=";
  };

  uses-ingress = true;

  extraOptions = {
    encryptKey = mkOption {
      description = mdDoc "This is the key used for encrypting sensitive data";
      type = types.str;
      default = "kite-default-encryption-key-change-in-production";
    };

    jwtSecret = mkOption {
      description = mdDoc "This is the key used for signing JWT tokens";
      type = types.str;
      default = "kite-default-jwt-secret-key-change-in-production";
    };
  };

  defaultValues = cfg: with cfg; {
    inherit encryptKey jwtSecret;
    host = ingress.domain;

    ingress = with cfg.ingress; {
      enabled = enable;
      className = ingressClassName;
      hosts = [{
        host = domain;
        paths = [{
          path = "/";
          pathType = "ImplementationSpecific";
        }];
      }];
      tls = [{ hosts = [ domain ]; }];
    };
  };
}
