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

  imports = [
    ../applications/adventureworks.nix
    ../applications/airflow.nix
    ../applications/alice-bitcoin.nix
    ../applications/alice-specter.nix
    ../applications/argo-events.nix
    # ../applications/argo-workflows.nix
    ../applications/authentik.nix
    ../applications/cloudbeaver.nix
    ../applications/demo.nix
    # ../applications/forgejo.nix
    # ../applications/harbor.nix
    ../applications/homer.nix
    ../applications/minio.nix
  ];
}
