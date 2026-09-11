{ secrets, ... }:
let
  apiKey = (secrets.xysat or { }).setupApiKey or "";
in
{
  services.xysat = {
    # Flip on once secrets.xysat.setupApiKey is set (`nur secrets edit`):
    # 1. Log into xyOps, Settings -> API Keys -> create a key with only the
    #    "add_servers" privilege (this key doesn't expire, unlike the 24h
    #    token in the UI's own "Add Server" install command).
    # 2. `nur secrets edit`, add `xysat.setupApiKey: <the key>`.
    # 3. Set enable = true here and `nur switch`.
    enable = true;

    setupUrl =
      if apiKey == "" then "" else "http://xyops.xyops:5522/api/app/satellite/config?t=${apiKey}";
  };
}
