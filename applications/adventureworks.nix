{ lib, ... }: {
  applications.adventureworks = {
    namespace = "adventureworks";
    createNamespace = true;

    helm.releases.adventureworks = {
      chart = lib.helm.downloadHelmChart {
        repo = "https://chart.kronkltd.net/";
        chart = "adventureworks";
        version = "0.1.0";
        chartHash = "sha256-GMqmF862sBNjYrdbbS1nl9Fw0jbfwo5vj3dEpxZXHu0=";
      };

      values = { };
    };
  };
}
