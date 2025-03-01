{ nixhelm, nixidy, system, ... }: {
  packages.generators.sops = nixidy.packages.${system}.generators.fromCRD {
    name = "sops";
    src = nixhelm.chartsDerivations.${system}.isindir.sops-secrets-operator;
    crds = [ "crds/isindir.github.com_sopssecrets.yaml" ];
  };
}
