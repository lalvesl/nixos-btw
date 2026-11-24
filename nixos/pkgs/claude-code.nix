# Claude Code from sadjow/claude-code-nix, which tracks releases faster than
# nixpkgs. Shared by the host and the sbx sandbox guest.
{ pkgs }:
let
  claude-code-src = fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/ab27a02c0f2d046e8d4ed53fb03c0649bdfae191.tar.gz";
    sha256 = "07hhbv0y6vbd66wkvf1qsnnzwpnwlh734xj2kg1yxvsaly216216";
  };
in
pkgs.callPackage "${claude-code-src}/package.nix" { }
