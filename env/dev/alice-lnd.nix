{ ... }:
{
  services.alice-lnd =
    let
      user-env = "alice";
    in
    {
      inherit user-env;
      enable = false;
      imageVersion = "v1.10.3";
      ingress.domain = "lnd-${user-env}.dinsro.com";
    };
}
