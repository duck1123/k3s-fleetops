{ ageRecipients, config, lib, pkgs, ... }:
with lib;
mkArgoApp { inherit config lib; } rec {
  name = "prowlarr";
  uses-ingress = true;

  extraOptions = {
    image = mkOption {
      description = mdDoc "The docker image";
      type = types.str;
      default = "linuxserver/prowlarr:latest";
    };

    service.port = mkOption {
      description = mdDoc "The service port";
      type = types.int;
      default = 9696;
    };

    storageClassName = mkOption {
      description = mdDoc "The storage class";
      type = types.str;
      default = "longhorn";
    };

    vpn = {
      enable = mkOption {
        description = mdDoc "Enable VPN routing through Mullvad";
        type = types.bool;
        default = true;
      };

      useSharedGluetun = mkOption {
        description = mdDoc "Use shared gluetun service instead of sidecar container";
        type = types.bool;
        default = false;
      };

      sharedGluetunService = mkOption {
        description = mdDoc "Service name for shared gluetun (e.g., gluetun.gluetun)";
        type = types.str;
        default = "gluetun.gluetun";
      };

      mullvadAccountNumber = mkOption {
        description = mdDoc "Mullvad account number (only used if useSharedGluetun is false)";
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
    };

    tz = mkOption {
      description = mdDoc "The timezone";
      type = types.str;
      default = "Etc/UTC";
    };

    pgid = mkOption {
      description = mdDoc "The group ID";
      type = types.int;
      default = 1000;
    };

    puid = mkOption {
      description = mdDoc "The user ID";
      type = types.int;
      default = 1000;
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
              # Configure DNS to use gluetun's DNS server when VPN is enabled
              dnsPolicy = if cfg.vpn.enable && !cfg.vpn.useSharedGluetun then "None" else "ClusterFirst";
              dnsConfig = lib.optionalAttrs (cfg.vpn.enable && !cfg.vpn.useSharedGluetun) {
                nameservers = [ "127.0.0.1" ];
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
              containers = lib.flatten [
                # Gluetun VPN container (only if VPN is enabled and not using shared gluetun)
                (lib.optional (cfg.vpn.enable && !cfg.vpn.useSharedGluetun) {
                  name = "gluetun";
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
                      value = "false";
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
                    (if cfg.vpn.serverCountry != null && cfg.vpn.serverCountry != "" then {
                      name = "SERVER_COUNTRIES";
                      value = cfg.vpn.serverCountry;
                    } else null)
                    (if cfg.vpn.serverLocation != "" then {
                      name = "SERVER_CITIES";
                      value = cfg.vpn.serverLocation;
                    } else null)
                    {
                      name = "FIREWALL_VPN_INPUT_PORTS";
                      value = "${toString cfg.service.port}";
                    }
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
                      value = "127.0.0.1";
                    }
                  ];
                  ports = [
                    {
                      containerPort = cfg.service.port;
                      name = "http";
                      protocol = "TCP";
                    }
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
                  ];
                  volumeMounts = [
                    {
                      mountPath = "/gluetun";
                      name = "gluetun";
                    }
                  ];
                })
                # Prowlarr container
                [{
                  inherit name;
                  image = cfg.image;
                  imagePullPolicy = "IfNotPresent";
                  env = [
                    {
                      name = "PGID";
                      value = "${toString cfg.pgid}";
                    }
                    {
                      name = "PUID";
                      value = "${toString cfg.puid}";
                    }
                    {
                      name = "TZ";
                      value = cfg.tz;
                    }
                  ] ++ (lib.optionalAttrs cfg.vpn.enable [
                    # Configure Prowlarr to use gluetun's HTTP proxy
                    {
                      name = "HTTP_PROXY";
                      value = if cfg.vpn.useSharedGluetun then
                        "http://${cfg.vpn.sharedGluetunService}:8888"
                      else
                        "http://127.0.0.1:8888";
                    }
                    {
                      name = "HTTPS_PROXY";
                      value = if cfg.vpn.useSharedGluetun then
                        "http://${cfg.vpn.sharedGluetunService}:8888"
                      else
                        "http://127.0.0.1:8888";
                    }
                    {
                      name = "NO_PROXY";
                      value = "localhost,127.0.0.1";
                    }
                  ]);
                  ports = [{
                    containerPort = cfg.service.port;
                    name = "http";
                    protocol = "TCP";
                  }];
                  volumeMounts = [
                    {
                      mountPath = "/config";
                      name = "config";
                    }
                  ];
                }]
              ];
              volumes = [
                {
                  name = "config";
                  persistentVolumeClaim.claimName = "${name}-${name}-config";
                }
              ] ++ (lib.optional (cfg.vpn.enable && !cfg.vpn.useSharedGluetun) {
                name = "gluetun";
                persistentVolumeClaim.claimName = "${name}-${name}-gluetun";
              });
            };
          };
        };
      };
    };

    ingresses.${name}.spec = with cfg.ingress; {
      inherit ingressClassName;

      rules = [{
        host = domain;

        http.paths = [{
          backend.service = {
            inherit name;
            port.name = "http";
          };

          path = "/";
          pathType = "ImplementationSpecific";
        }];
      }];

      tls = [{ hosts = [ domain ]; }];
    };

    persistentVolumeClaims = {
      "${name}-${name}-config".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "5Gi";
      };
    } // (lib.optionalAttrs (cfg.vpn.enable && !cfg.vpn.useSharedGluetun) {
      "${name}-${name}-gluetun".spec = {
        inherit (cfg) storageClassName;
        accessModes = [ "ReadWriteOnce" ];
        resources.requests.storage = "1Gi";
      };
    });

    services.${name}.spec = {
      ports = [{
        name = "http";
        port = cfg.service.port;
        protocol = "TCP";
        targetPort = "http";
      }];

      selector = {
        "app.kubernetes.io/instance" = name;
        "app.kubernetes.io/name" = name;
      };

      type = "ClusterIP";
    };

    # Create SOPS secret for Mullvad account number (only if not using shared gluetun)
    sopsSecrets = lib.optionalAttrs (cfg.vpn.enable && !cfg.vpn.useSharedGluetun) {
      "${name}-mullvad-account" = lib.createSecret {
        inherit ageRecipients lib pkgs;
        namespace = cfg.namespace;
        secretName = "${name}-mullvad-account";
        values.accountNumber = cfg.vpn.mullvadAccountNumber;
      };
    };
  };
}

