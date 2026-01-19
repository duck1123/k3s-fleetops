{
  pkgs,
  chartTgz,
  chartName,
}:

pkgs.runCommand chartName { inherit chartTgz; } ''
  mkdir -p $out
  tar -xzf ${chartTgz} -C $out --strip-components=1
  echo "Extracted Helm chart: $chartName"
''
