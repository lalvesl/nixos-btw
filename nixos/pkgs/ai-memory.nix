# ai-memory built with nixpkgs' own Rust toolchain instead of the pinned
# rust-overlay one its flake uses.
#
# The flake's package is made with a prebuilt rustc from rust-overlay (channel
# 1.95, "minimal" profile). That binary dies with a segmentation fault when it
# runs under qemu-user, which is how the Orange Pi pipeline builds x86_64
# packages, so the pipeline could never build ai-memory. nixpkgs' rustc runs
# fine there, and it is newer (1.99) than the 1.95 the project asks for.
#
# Same source, same Cargo.lock, same install steps as upstream's package. When
# the upstream flake lets a consumer pick the Rust toolchain, drop this file and
# use its package again.
{ pkgs, src }:
pkgs.rustPlatform.buildRustPackage {
  pname = "ai-memory";
  version = (builtins.fromTOML (builtins.readFile "${src}/Cargo.toml")).workspace.package.version;

  inherit src;
  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "zip-8.6.0" = "sha256-cnLvGK9nhGeYqJYA6kjlYTYChH0fXs2q27rWvHEZWpg=";
    };
  };

  # nixpkgs' rustPlatform points the -sys crates at the system libraries through
  # pkg-config (RUSTONIG_SYSTEM_LIBONIG, ZSTD_SYS_USE_PKG_CONFIG, LIBGIT2_NO_VENDOR and the system SQLite), which the
  # upstream toolchain does not do, so they have to be provided here.
  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [
    pkgs.libgit2
    pkgs.oniguruma
    pkgs.sqlite
    pkgs.zlib
    pkgs.zstd
  ];

  # Skip the Tailwind CLI download in the sandbox; the build falls back to the
  # stylesheet committed to the repository.
  TAILWIND_SKIP = "1";
  buildType = "release";
  doCheck = false;

  postInstall = ''
    mkdir -p $out/share/ai-memory
    cp -a hooks $out/share/ai-memory/

    mkdir -p $out/etc/ai-memory
    cp crates/ai-memory-cli/templates/config.default.toml \
       $out/etc/ai-memory/config.default.toml
  '';

  meta = {
    description = "Long-term memory for AI coding agents";
    homepage = "https://aimemory.sh";
    license = pkgs.lib.licenses.mit;
    mainProgram = "ai-memory";
  };
}
