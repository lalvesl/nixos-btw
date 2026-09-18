# Memory and swap policy for the whole stack.
#
# 16 GB sounds like plenty until you add up JVM heap, PHP-FPM workers, a .NET
# transcoder and a CI runner. The aim here is not to squeeze more in; it is to
# make the failure mode predictable. Without limits the kernel OOM killer picks
# a victim by heuristic, and on a box like this it tends to pick the largest
# long-running process -- which is usually the one you care about most.
{ ... }:
{
  # Compressed swap in RAM rather than swap on eMMC. Writing swap to flash on a
  # board that also stores its own root filesystem there wears the device and is
  # slower than compressing. zstd buys roughly 3x on typical anonymous pages.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  # With zram present, leaning on swap earlier is the right trade: a compressed
  # page costs microseconds, an OOM kill costs a service.
  boot.kernel.sysctl = {
    "vm.swappiness" = 120;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
  };

  # Nothing to enable for MemoryMax and CPUWeight: cgroup v2 is the only
  # hierarchy systemd will boot under now, and accounting comes with it.
}
