{ ... }:
{
  # Cap the dirty page cache. The default is a share of RAM (20 % of 15 GB, about
  # 3 GB), so a long write -- a copy, a build, a browser cache -- piles up data in
  # memory and then throttles every process that writes while it is flushed, which
  # shows up as the desktop stalling for a moment. Start flushing at 64 MiB and
  # never hold more than 256 MiB dirty: plenty for an NVMe, and the stalls stay
  # short.
  boot.kernel.sysctl = {
    "vm.dirty_background_bytes" = 67108864;
    "vm.dirty_bytes" = 268435456;
  };
}
