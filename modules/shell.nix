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
            babashka
            clojure
            docker
            gum
            jet
            keepassxc
            kubectl
            kubernetes-helm
            kubeseal
            openssl
            sops
            ssh-to-age
            ssh-to-pgp
            yq
          ];
        };
    };
}
