{ ... }:
{
  # pubkey/relays/NIP-05 are hardcoded in applications/duck1123-site/ (a real
  # npm/Vite project, not per-env Nix options) since this is a single-identity
  # site — see applications/duck1123-site/src/config.js and
  # public/.well-known/nostr.json to change them.
  services.duck1123.enable = true;
}
