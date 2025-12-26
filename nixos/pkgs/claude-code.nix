# Claude Code from sadjow/claude-code-nix, which tracks releases faster than
# nixpkgs. Shared by the host and the sbx sandbox guest.
{ pkgs }:
let
  claude-code-src = fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/02cb98e535e518b992598bea883a7f6393ca5b8c.tar.gz";
    sha256 = "03nvz3xybn3blfl7jqm48mhgwqgmmkw1wfzywhab2rkmpdqd00wh";
  };
in
pkgs.callPackage "${claude-code-src}/package.nix" { }
