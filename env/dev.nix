{ lib, ... }: {
  nixidy = {
    defaults.syncPolicy.autoSync = {
      enabled = true;
      prune = true;
      selfHeal = true;
    };

    target = {
      repository = "https://github.com/duck1123/k3s-fleetops.git";
      branch = "master";
      rootPath = "./manifests/dev";
    };
  };
}
