{ ... }:
{
  flake.nixidyApps.xysat =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    with lib;
    let
      name = "xysat";
      setup-secret = "${name}-setup";
    in
    self.lib.mkArgoApp
      {
        inherit
          config
          lib
          self
          pkgs
          ;
      }
      {
        inherit name;

        # The bootstrap URL (http://xyops.xyops:5522/api/app/satellite/config?t=API_KEY)
        # embeds a non-expiring API Key generated from the xyOps UI (Settings ->
        # API Keys, "add_servers" privilege only) -- there's no way to mint this
        # ahead of time from Nix, since it's issued by the running conductor.
        # See env/dev/xysat.nix for how it's wired from secrets.xysat.setupApiKey.
        sopsSecrets =
          cfg:
          optionalAttrs (cfg.setupUrl != "") {
            ${setup-secret}.SETUP_URL = cfg.setupUrl;
          };

        extraOptions = {
          image = mkOption {
            description = mdDoc "The xySat container image";
            type = types.str;
            default = "ghcr.io/pixlcore/xysat:latest";
          };

          setupUrl = mkOption {
            description = mdDoc ''
              Full bootstrap URL including a non-expiring API Key, e.g.
              http://xyops.xyops:5522/api/app/satellite/config?t=YOUR_API_KEY
              Only consulted on first launch per node -- once /etc/xysat/config.json
              exists on a node (persisted via hostConfigDir), it's skipped on restart.
            '';
            type = types.str;
            default = "";
          };

          hostConfigDir = mkOption {
            description = mdDoc "Host directory (bind-mounted per node) holding this node's persistent xySat config/server identity";
            type = types.str;
            default = "/var/lib/xysat";
          };
        };

        extraResources =
          cfg:
          let
            labels = {
              "app.kubernetes.io/instance" = name;
              "app.kubernetes.io/name" = name;
            };
          in
          {
            daemonSets.${name} = {
              metadata.labels = labels;

              spec = {
                selector.matchLabels = labels;

                template = {
                  metadata.labels = labels;

                  spec = {
                    # Real host visibility (CPU/mem/process/network), not just this
                    # container's own cgroup -- and lets cluster DNS still resolve
                    # (needed since hostNetwork changes the default DNS policy).
                    hostNetwork = true;
                    hostPID = true;
                    dnsPolicy = "ClusterFirstWithHostNet";

                    # Run on every node, including the nasnix control-plane node.
                    tolerations = [
                      { operator = "Exists"; }
                    ];

                    containers = [
                      {
                        inherit name;
                        image = cfg.image;
                        imagePullPolicy = "IfNotPresent";

                        env = [
                          {
                            name = "XYSAT_config_file";
                            value = "/etc/xysat/config.json";
                          }
                        ]
                        ++ optionals (cfg.setupUrl != "") [
                          {
                            name = "XYOPS_setup";
                            valueFrom.secretKeyRef = {
                              name = setup-secret;
                              key = "SETUP_URL";
                            };
                          }
                        ];

                        volumeMounts = [
                          {
                            mountPath = "/etc/xysat";
                            name = "conf";
                          }
                        ];
                      }
                    ];

                    volumes = [
                      {
                        name = "conf";
                        hostPath = {
                          path = cfg.hostConfigDir;
                          type = "DirectoryOrCreate";
                        };
                      }
                    ];
                  };
                };
              };
            };
          };
      };
}
