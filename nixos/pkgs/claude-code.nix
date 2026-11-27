# Claude Code from sadjow/claude-code-nix, which tracks releases faster than
# nixpkgs. Shared by the host and the sbx sandbox guest.
{ pkgs }:
let
  claude-code-src = fetchTarball {
    url = "https://github.com/sadjow/claude-code-nix/archive/19faa670a1e75f6fb055ae401b5d3d792371e077.tar.gz";
    sha256 = "0s50jf1r0ckbh4v29vnnjz4imb3cdmzvy6vd42d3sb3azcwngsn0";
  };
in
pkgs.callPackage "${claude-code-src}/package.nix" { }
