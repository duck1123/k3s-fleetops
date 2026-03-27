{ ... }:
{
  flake.nixidyApps.metallb =
    {
      charts,
      config,
      lib,
      self,
      ...
    }:
    with lib;
    self.lib.mkArgoApp { inherit config lib; } {
      name = "metallb";
      namespace = "metallb-system";

      # https://artifacthub.io/packages/helm/metallb/metallb
      chart = charts.metallb.metallb;

      extraOptions = {
        l2 = {
          poolName = mkOption {
            description = mdDoc "IPAddressPool resource name";
            type = types.str;
            default = "default-pool";
          };

          advertisementName = mkOption {
            description = mdDoc "L2Advertisement resource name";
            type = types.str;
            default = "default-l2";
          };

          addresses = mkOption {
            description = mdDoc ''
              IP ranges MetalLB may hand out (L2 mode). Examples: `192.168.1.50-192.168.1.60`, `192.168.1.0/24`.
              Leave empty to install MetalLB only; configure pools manually (e.g. IPAddressPool + L2Advertisement CRs).
            '';
            type = types.listOf types.str;
            default = [ ];
          };
        };
      };

      defaultValues = cfg: {
        prometheus.scrapeAnnotations = false;
        prometheus.rbacPrometheus = false;
      };

      extraAppConfig =
        cfg:
        let
          ns = cfg.namespace;
          inherit (cfg.l2) poolName advertisementName addresses;
          poolYaml = ''
            apiVersion: metallb.io/v1beta1
            kind: IPAddressPool
            metadata:
              name: ${poolName}
              namespace: ${ns}
            spec:
              addresses:
            ${concatMapStringsSep "\n" (a: "            - ${a}") addresses}
          '';
          l2Yaml = ''
            apiVersion: metallb.io/v1beta1
            kind: L2Advertisement
            metadata:
              name: ${advertisementName}
              namespace: ${ns}
            spec:
              ipAddressPools:
                - ${poolName}
          '';
        in
        mkIf (addresses != [ ]) { yamls = [ (poolYaml + "---\n" + l2Yaml) ]; };
    };
}
