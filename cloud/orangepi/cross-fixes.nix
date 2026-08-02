{ ... }:
{
  # systemd's BPF programs are compiled by an unwrapped clang targeting `bpf`,
  # which does not pick up the aarch64 sysroot when cross-compiling from
  # x86_64. The build fails on `linux/types.h` / `errno.h` not being found.
  # Disabling the BPF framework drops RestrictFileSystems=,
  # RestrictNetworkInterfaces=, SocketBind*= and IPAddress{Allow,Deny}=
  # enforcement (units using them still start, with a warning).
  nixpkgs.overlays = [
    (final: prev: {
      systemd = prev.systemd.override { withLibBPF = false; };
    })
  ];
}
