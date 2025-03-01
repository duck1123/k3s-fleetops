{ ... }: {
  nixidy = {
    target = {
      repository = "https://github.com/duck1123/k3s-fleetops.git";
      branch = "main";
      rootPath = "manifests/dev";
    };
    defaults.syncPolicy = {
      autoSync = {
        enabled = true;
        prune = true;
        selfHeal = true;
      };
    };
  };
}
