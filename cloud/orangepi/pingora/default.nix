{
  lib,
  rustPlatform,
  cmake,
  perl,
}:

rustPlatform.buildRustPackage {
  pname = "homelab-gateway";
  version = "0.1.0";

  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;

  # The TLS backend is rustls, so there is no OpenSSL to find. cmake and perl
  # remain for the ring/aws-lc build scripts further down the tree.
  nativeBuildInputs = [
    cmake
    perl
  ];

  meta = {
    description = "Pingora gateway separating tailnet traffic from Cloudflare tunnel traffic";
    mainProgram = "homelab-gateway";
    platforms = lib.platforms.linux;
  };
}
