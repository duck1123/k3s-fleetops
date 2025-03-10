{ charts, config, lib, pkgs, ... }:
let
  cfg = config.services.postgresql;

  chart = lib.helmChart {
    inherit pkgs;
    chartTgz = ../../charts/postgresql-16.2.3.tgz;
    chartName = "postgresql";
  };

  defaultNamespace = "postgresql";

  defaultValues = {
    global.postgresql.auth = {
      existingSecret = "postgresql-password";
      secretKeys = {
        adminPasswordKey = "adminPassword";
        userPasswordKey = "userPassword";
        replicationPasswordKey = "replicationPassword";
      };
    };
  };

  values = lib.attrsets.recursiveUpdate defaultValues cfg.values;
  namespace = cfg.namespace;
in with lib; {
  options.services.postgresql = {
    enable = mkEnableOption "Enable application";

    namespace = mkOption {
      description = mdDoc "The namespace to install into";
      type = types.str;
      default = defaultNamespace;
    };

    values = mkOption {
      description = "All the values";
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = mkIf cfg.enable {
    applications.postgresql = {
      inherit namespace;
      createNamespace = true;
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ];
      helm.releases.postgresql = { inherit chart values; };
      syncPolicy.finalSyncOpts = [ "CreateNamespace=true" ];

      resources.sealedSecrets.postgresql-password.spec = {
        encryptedData = {
          adminPassword =
            "AgAuCfDiWwOSOKwjkex0B5euFlS0GwQoB+jLkJ4uRSF+n8qT+Pgu6PweF74XVieA7xhMjuJvUrYcuDydYMko8hTclhXv2Z/lJKp3i/FeYK/cwRqUACuOMYKZAZT2Vfpf9Ry3uZbG7LxPZd3zw4hC2KmURhhb2JamvLI5o0sWEepRa7MzSjpk7cfTVekvR0/pvChefPpPeE3jqhbH68jqRAp+v4D9KmxfmCQfOfCecOAJ2XE5KFifjFxevGfMWdtmbxdl3unLePm4hB/hJlTYnihyOTwUu7EO2Ol+seFUCT7HQXUMfw0UJH3AP7aBiLh63k438P/uP8W+cbUIozm3n17Tx6gRBtjanrpkqAyCA2aMiFFRpHGhVb0ZaVRh7co5J1SdnjNUzijt4V22l8fFG+CPcskUGklYDLdl5YgAJNYN1VziXqyxjrhP2YLUK1633mZCA587mRq/2raucUWJB9z6yVQkPpv/Vd6MYq2JpDzaDDIOZyw1Xk7gcB+sUQ7CsiKMMsDAgE43a8q/dz1ADoBFbhnhYDAJtwtycj5Yv4Xp2RVV/bCm1kEe3ysaA9HXzFD1/YN/C+LpqzfiMVAhdsZGn7UG2JpnKtUC8AS6Ek75z9452qCvVjtvQrC+Crofp23X7giMY2C4ff7OsLIJQlMxEH2JXUwwF9mvt7439C+2MWFxMx295VQunh0UQosI8ap5H3b3pLzAB8h9EUj0ZNlDLlbTpA==";
          adminUsername =
            "AgCzNBLNKaNmUNRFJpmalmDpYBJ4QC3wNF/+t1tfOSd17f+Ee63qsKBTisVHVoyqT/qXCf1Rltr7kgOnDh74BrehGqVruLjY9YRAWH14Dw1o1KslJZ/xtKFPHZ+/JQGpgFbw1pPERIhkuDCnGHvg+xClpwM0cYHLTm0rwmSEfCjtK2fZ23NgGdTtkaJpkpT7kIbwyspmIJRAeirNo8BvlkB2ENW8nBeGy4JvVH0qhWlH6cdS0VVivU0gzVwTzwjApZzhjS/yUTsnEbQjFtOTRkRPhQ+M1vYEo8n6LutP2VN4XUomb+nH9U1kcN+jpDCxNxYEiV1yYQjP+2lEo+P1UTAEOzUG/8u1a61nezksRGlqI58CYPE87ORVpfczirVwOHHN1vUDkRJxzL/z2HLCknvHRyRMLCytlQimV/yaVfnPh53zEana3IXv1l3tWV4mZ+opPbr3xNr6C/LBZsGbNuaeZPY0236VLURJC7LCePNPdsXEE10BG2lUkEXagWKqknS33WF3HcFfVN82Nb2FQSTpzGdIh2XGd+yMRc0YaubC6aSUsadmyUh9smzlju9AW9P061txl8a+NTwlQPxboazEKqW5FurD7dUdHWUOXR1o26/yJC+rzd39eITRtDiL3bt4j+CqXW600HzMLqLJZ4rP2rzDUE7ze0bzsBW/wlfCi7nsd5TYEKvijV+jxmUPbXvWi24EKBEh6g==";
          replicationPassword =
            "AgC+NQAzQkpXXNFgstJZEs1Ex0G1mVrk5pvGNIlZMz3EET3SOWHQ1i/rsQZ0G9s2WKKPMmc6ZtsK+tuG42nVDU+KOgGmgW+WfisT4TW1Y4lO1d1IguBrk3wue7GttlJ7+FsXdpbUH8UhGELHJyXXraqQ86gTD9B1yw+mbIHhvKdVltn5Jtg/dDEVPSYJgKIdf+jerGvG0JNJL9wU1WKY/DA8H/9qIVtoOW0iL+/mvRNqOyW6UeM29eBU4RcRTaLN8TKJ+H/8hbJ4qeqE+3LDeNJ8224wUuEYxI2jL5ulMnve4oOfDy4+7YagLhXrFWroCBkp8DuXnk9mgIQNpZt7AZLgWGzNErgy8CSvUWITYihh+/RNEAiFx4AyWjhin879DfFTHSh65tPLpyCUvfJXpBwJ56W66gLjrmvZPyubKcrJDwbIZkz2qOD4rnUorhkgxEEH0BZLJ0Ny0CGMbG3/yB4rXx1mN1+mTRDFhnpAi0okXVhx0J9IKkAIL/eJ2k3bEb9tglVAvl9FoRq7ujvEZ60CMuKPO6swTPkmLKzbl0OJ88KD9xQ7Yfn5QA5oHYwB5MB2QXSPyo5TASjQpTBQH2hR47lOyz/tLVbbXH9KsrwtdWTT/FdeZwbIYAjQAycey7MjRBMRkxADk0ncW7zjDSS4qJJhdmSUun8brxWBJRqefte59tqcCZKshrDW0dVjjuova6yLpJoDzYWX4F4v7SW8ipQHew==";
          userPassword =
            "AgCeMHlq57eE8tB0UERX6XCYPO26Vgd0/8EddQrt01G6RP4Mq5bKcZYIlX8zJTpRpqqgBeqT5MxJ3AXKonC9yseI9mWaIczh4p11xtUpXwGSE7Q3WpRQCNfnNYbScmoEwUCMpv+OZ360dAHQ1wm94FDeOVmfTVZNVq7KvHv3tVNyNAV2qsppdLLYdxteo6S8usyAMShoKzRrpHqvNmRyXxL5eck86MP2/SotHwq3/DuLGfOr8YXx5Ff8S4K2Mq+ProCTvvNop4CCkJPVf8iIxoQjcYmAwOCOrfv3hyoSqX848jw3U19XFwPc5UwGk2qZMdFfGh2azNyH4aZVy3vXMbtt+j10HlxPVndLVxKZJNoOPNujeozb9F7GDhUciDzNXWDMYKJdzyyZovHVbtLB1GUtOaX0pKL0vIBSdfC/PZer/Y/DybBchSmBrhFyIEDtMDaPBwkumcIFOzx8GmvRCZhA3r43u2K8FDs8HLr/A3A9GKw4FaCBCO7MUylAkeh7cspGxRBzO7zIFdHgImRTe7KhexMORH9eEUmNeuJdrGKP2sqCPKBHkX+0m0YBV3oGfA9klruVdVXjEc5iG7pb2UrIDRKui1S1u5YNjuRm8gVWGUS+mqWIY5v6NEXK+ou118uFtaYgT8pSpXiWvhH7U0D6zC/ArFVDISSImBlCLTBetVlDCfdujHJ+ZODpTj8XNE4gV1odQn7gve9sfWlvIEI+l8aIig==";
        };

        template.metadata = {
          creationTimestamp = null;
          name = "postgresql-password";
          namespace = cfg.namespace;
        };
      };
    };
  };
}
