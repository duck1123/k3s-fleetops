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

    enableIPv6 = mkOption {
      description = mdDoc ''
        Enable IPv6 support. This requires:
        1. Kubernetes cluster with dual-stack networking enabled
        2. CNI plugin that supports IPv6 (e.g., Cilium, Calico with IPv6)
        3. IPv6 addresses assigned to nodes
        4. IPv6 routing configured in the cluster

        If IPv6 is not properly configured in your cluster, you'll see
        "Network unreachable" errors. In that case, set this to false.
      '';
      type = types.bool;
      default = false;
    };

    logLevel = mkOption {
      description = mdDoc "Log level (debug, info, warning, error). Use 'debug' for maximum verbosity.";
      type = types.str;
      default = "info";
    };

    controlServer = {
      username = mkOption {
        description = mdDoc "HTTP control server username";
        type = types.str;
        default = "";
      };

      password = mkOption {
        description = mdDoc "HTTP control server password";
        type = types.str;
        default = "";
      };
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
                # Use gluetun's internal DNS server (listening on port 53)
                # This ensures DNS queries go through the VPN and aren't blocked by firewall
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
              containers = [{
                inherit name;
                image = "qmcgaw/gluetun:latest";
                imagePullPolicy = "IfNotPresent";
                securityContext = {
                  capabilities.add = [ "NET_ADMIN" "MKNOD" "NET_RAW" ];
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
                    value = if cfg.enableIPv6 then "true" else "off";
                  }
                  (if !cfg.enableIPv6 then {
                    name = "SERVER_ADDRESS_IPV6";
                    value = "off";
                  } else null)
                  (if !cfg.enableIPv6 then {
                    name = "MULLVAD_SERVER_IPV6";
                    value = "off";
                  } else null)
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
                    value = "on";
                  }
                  {
                    name = "FIREWALL_VPN_INPUT_PORTS";
                    value = "8888,8000";
                  }
                  {
                    name = "LOG_LEVEL";
                    value = cfg.logLevel;
                  }
                  {
                    name = "LOG_CALLER";
                    value = "on";
                  }
                  {
                    name = "HTTPPROXY_LOG";
                    value = "on";
                  }
                  {
                    name = "HTTPPROXY_LOG_LEVEL";
                    value = "info";
                  }
                  {
                    name = "HTTPPROXY_LOG_HEADERS";
                    value = "on";
                  }
                  {
                    name = "OPENVPN_VERBOSITY";
                    value = "3";
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
                    name = "HTTP_CONTROL_SERVER";
                    value = "on";
                  }
                  {
                    name = "DNS_KEEP_NAMESERVER";
                    value = "off";
                  }
                  {
                    name = "DNS_ADDRESS";
                    value = if cfg.enableIPv6 then "::" else "";
                  }
                  {
                    name = "DNS_IPV6";
                    value = if cfg.enableIPv6 then "on" else "off";
                  }
                  {
                    name = "DNS_UPSTREAM_IPV6";
                    value = if cfg.enableIPv6 then "on" else "off";
                  }
                  {
                    name = "HTTPPROXY";
                    value = "on";
                  }
                  {
                    name = "HTTPPROXY_LISTENING_ADDRESS";
                    value = "0.0.0.0:8888";
                  }
                  {
                    name = "HTTP_CONTROL_SERVER_LISTENING_ADDRESS";
                    value = "0.0.0.0:8000";
                  }
                  (if cfg.controlServer.username != "" then {
                    name = "HTTP_CONTROL_SERVER_USER";
                    valueFrom.secretKeyRef = {
                      name = "${name}-control-server";
                      key = "username";
                    };
                  } else null)
                  (if cfg.controlServer.password != "" then {
                    name = "HTTP_CONTROL_SERVER_PASSWORD";
                    valueFrom.secretKeyRef = {
                      name = "${name}-control-server";
                      key = "password";
                    };
                  } else null)
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
                  exec = {
                    command = [
                      "sh"
                      "-c"
                      ''
                        # First check VPN is connected
                        VPN_STATUS=$(wget -q -O- --timeout=2 http://127.0.0.1:8000/v1/openvpn/status 2>/dev/null || echo "")
                        if [ -z "$VPN_STATUS" ] || ! echo "$VPN_STATUS" | grep -q '"status":"running"'; then
                          exit 1
                        fi
                        # Test proxy port is listening and accepting connections
                        # Use nc (netcat) to test if port is open (works with BusyBox)
                        if ! echo "" | timeout 2 nc 127.0.0.1 8888 >/dev/null 2>&1; then
                          exit 1
                        fi
                        exit 0
                      ''
                    ];
                  };
                  initialDelaySeconds = 30;
                  periodSeconds = 10;
                  timeoutSeconds = 5;
                  successThreshold = 1;
                  failureThreshold = 3;
                };
                startupProbe = {
                  exec = {
                    command = [
                      "sh"
                      "-c"
                      ''
                        # Check if VPN is connected using localhost (may not require auth)
                        wget -q -O- --timeout=2 http://127.0.0.1:8000/v1/openvpn/status 2>/dev/null | grep -q '"status":"running"' || exit 1
                      ''
                    ];
                  };
                  initialDelaySeconds = 10;
                  periodSeconds = 5;
                  timeoutSeconds = 3;
                  successThreshold = 1;
                  failureThreshold = 30;
                };
                livenessProbe = {
                  tcpSocket = {
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
        {
          name = "http-control";
          port = 8000;
          protocol = "TCP";
          targetPort = "http-control";
        }
      ];

      selector = {
        "app.kubernetes.io/instance" = name;
        "app.kubernetes.io/name" = name;
      };

      type = "ClusterIP";
      # Enable dual-stack if IPv6 is enabled and cluster supports it
      ipFamilyPolicy = if cfg.enableIPv6 then "RequireDualStack" else null;
      ipFamilies = if cfg.enableIPv6 then [ "IPv4" "IPv6" ] else [ "IPv4" ];
    };

    # Create SOPS secrets
    sopsSecrets = {
      "${name}-mullvad-account" = lib.createSecret {
        inherit ageRecipients lib pkgs;
        namespace = cfg.namespace;
        secretName = "${name}-mullvad-account";
        values.accountNumber = cfg.mullvadAccountNumber;
      };
    } // lib.optionalAttrs (cfg.controlServer.username != "" || cfg.controlServer.password != "") {
      "${name}-control-server" = lib.createSecret {
        inherit ageRecipients lib pkgs;
        namespace = cfg.namespace;
        secretName = "${name}-control-server";
        values = let
          # Create basic auth header: Basic base64(username:password)
          authHeader = "Basic " + (builtins.readFile (
            pkgs.runCommand "gluetun-auth-header" { } ''
              echo -n "${cfg.controlServer.username}:${cfg.controlServer.password}" | ${pkgs.coreutils}/bin/base64 > $out
            ''
          ));
        in {
          username = cfg.controlServer.username;
          password = cfg.controlServer.password;
          authHeader = authHeader;
        };
      };
    };
  };
}

