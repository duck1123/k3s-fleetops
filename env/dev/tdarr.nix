{ config, ... }:
{
  services.tdarr = {
    enable = true;
    image = "ghcr.io/haveagitgat/tdarr:2.86.01";
    healthcheckcpuWorkers = 0;
    healthcheckgpuWorkers = 1;
    hostAffinity = "nixmini";

    ingressProvider = "traefik-lan";
    ingress.tls.enable = true;

    nfs = {
      enable = true;
      server = config.devDefaults.nasHost;
      path = config.devDefaults.nasBase;
    };

    puid = 1000;
    pgid = 1000;

    replicas = 0;
    storageClassName = "longhorn";
    useProbes = false;
    vpn.enable = false;
    enableGPU = true;
    enableNvidiaGPU = false;
    transcodecpuWorkers = 0;
    transcodegpuWorkers = 0;
  };
}
