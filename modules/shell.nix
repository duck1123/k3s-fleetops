{ inputs, ... }:
{
  # inputs.make-shell.url = "github:nicknovitski/make-shell";

  imports = [ inputs.make-shell.flakeModules.default ];

  perSystem =
    { system, ... }:
    {
      make-shells.default =
        { pkgs, ... }:
        {
          packages = with pkgs; [
            inputs.nixidy.packages.${system}.default
            age
            argo-workflows
            argocd
            autokuma # provides the `kuma` CLI (kuma-cli) and `autokuma` binaries
            gum
            jet
            kubectl
            kubernetes-helm
            kubeseal
            nix-output-monitor
            openssl
            sops
            ssh-to-age
            ssh-to-pgp
            yq
          ];
        };
    };
}
