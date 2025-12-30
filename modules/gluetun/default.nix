{ ageRecipients, config, lib, pkgs, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "gluetun";
  uses-ingress = false;

  extraOptions = {
    storageClassName = mkOption {
      description = mdDoc "The storage class";
      type = types.str;
      default = "longhorn";
    };

    mullvadAccountNumber = mkOption {
      description = mdDoc "Mullvad account number";
      type = types.str;
      default = "";
    };

    serverLocation = mkOption {
      description = mdDoc "Mullvad server location (e.g., us-was, se-sto)";
      type = types.str;
      default = "";
    };

    serverCountry = mkOption {
      description = mdDoc "Mullvad server country (e.g., USA, Sweden)";
      type = types.nullOr types.str;
      default = null;
    };

    tz = mkOption {
      description = mdDoc "The timezone";
      type = types.str;
      default = "Etc/UTC";
    };
  };

  extraResources = cfg: {
    deployments = {
      ${name} = {
        metadata.labels = {
          "app.kubernetes.io/instance" = name;
          "app.kubernetes.io/name" = name;
          "app.kubernetes.io/version" = "latest";
        };

        spec = {
          selector.matchLabels = {
            "app.kubernetes.io/instance" = name;
            "app.kubernetes.io/name" = name;
          };

          template = {
            metadata.labels = {
              "app.kubernetes.io/instance" = name;
              "app.kubernetes.io/name" = name;
            };

            spec = {
              automountServiceAccountToken = true;
              serviceAccountName = "default";
              dnsPolicy = "None";
              dnsConfig = {
                nameservers = [ "1.1.1.1" "1.0.0.1" "2606:4700:4700::1111" ];
                searches = [ ];
                options = [
                  {
                    name = "ndots";
                    value = "2";
                  }
                  {
                    name = "edns0";
                  }
                ];
              };
              containers = [{
                inherit name;
                image = "qmcgaw/gluetun:latest";
                imagePullPolicy = "IfNotPresent";
                securityContext = {
                  capabilities.add = [ "NET_ADMIN" "MKNOD" ];
                  privileged = false;
                };
                env = lib.filter (x: x != null) [
                  {
                    name = "VPN_SERVICE_PROVIDER";
                    value = "mullvad";
                  }
                  {
                    name = "VPN_TYPE";
                    value = "openvpn";
                  }
                  {
                    name = "OPENVPN_IPV6";
                    value = "true";
                  }
                  {
                    name = "MULLVAD_ACCOUNT_NUMBER";
                    valueFrom.secretKeyRef = {
                      name = "${name}-mullvad-account";
                      key = "accountNumber";
                    };
                  }
                  {
                    name = "OPENVPN_USER";
                    valueFrom.secretKeyRef = {
                      name = "${name}-mullvad-account";
                      key = "accountNumber";
                    };
                  }
                  (if cfg.serverCountry != null && cfg.serverCountry != "" then {
                    name = "SERVER_COUNTRIES";
                    value = cfg.serverCountry;
                  } else null)
                  (if cfg.serverLocation != "" then {
                    name = "SERVER_CITIES";
                    value = cfg.serverLocation;
                  } else null)
                  {
                    name = "FIREWALL";
                    value = "on";
                  }
                  {
                    name = "FIREWALL_DEBUG";
                    value = "off";
                  }
                  {
                    name = "UPDATER_PERIOD";
                    value = "24h";
                  }
                  {
                    name = "TZ";
                    value = cfg.tz;
                  }
                  {
                    name = "HTTP_CONTROL_SERVER_LOG";
                    value = "on";
                  }
                  {
                    name = "DNS_KEEP_NAMESERVER";
                    value = "off";
                  }
                  {
                    name = "DNS_ADDRESS";
                    value = "::";
                  }
                  {
                    name = "DNS_IPV6";
                    value = "on";
                  }
                  {
                    name = "DOT_IPV6";
                    value = "on";
                  }
                  {
                    name = "HTTPPROXY";
                    value = "on";
                  }
                  {
                    name = "HTTPPROXY_LISTENING_ADDRESS";
                    value = ":8888";
                  }
                  {
                    name = "HTTP_CONTROL_SERVER_LISTENING_ADDRESS";
                    value = ":8000";
                  }
                ];
                ports = [
                  {
                    containerPort = 8888;
                    name = "http-proxy";
                    protocol = "TCP";
                  }
                  {
                    containerPort = 1080;
                    name = "socks-proxy";
                    protocol = "TCP";
                  }
                  {
                    containerPort = 8000;
                    name = "http-control";
                    protocol = "TCP";
                  }
                ];
                readinessProbe = {
                  httpGet = {
                    path = "/v1/openvpn/status";
                    port = 8000;
                  };
                  initialDelaySeconds = 10;
                  periodSeconds = 10;
                  timeoutSeconds = 5;
                  successThreshold = 1;
                  failureThreshold = 3;
                };
                livenessProbe = {
                  httpGet = {
                    path = "/v1/openvpn/status";
                    port = 8000;
                  };
                  initialDelaySeconds = 30;
                  periodSeconds = 30;
                  timeoutSeconds = 5;
                  successThreshold = 1;
                  failureThreshold = 3;
                };
                volumeMounts = [
                  {
                    mountPath = "/gluetun";
                    name = "gluetun";
                  }
                ];
              }];
              volumes = [
                {
                  name = "gluetun";
                  persistentVolumeClaim.claimName = "${name}-${name}-gluetun";
                }
              ];
            };
          };
        };
      };
    };

    persistentVolumeClaims = {
      "${name}-${name}-gluetun".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "1Gi";
      };
    };

    services.${name}.spec = {
      ports = [
        {
          name = "http-proxy";
          port = 8888;
          protocol = "TCP";
          targetPort = "http-proxy";
        }
        {
          name = "socks-proxy";
          port = 1080;
          protocol = "TCP";
          targetPort = "socks-proxy";
        }
      ];

      selector = {
        "app.kubernetes.io/instance" = name;
        "app.kubernetes.io/name" = name;
      };

      type = "ClusterIP";
    };

    # Create SOPS secret for Mullvad account number
    sopsSecrets."${name}-mullvad-account" = lib.createSecret {
      inherit ageRecipients lib pkgs;
      namespace = cfg.namespace;
      secretName = "${name}-mullvad-account";
      values.accountNumber = cfg.mullvadAccountNumber;
    };
  };
}

