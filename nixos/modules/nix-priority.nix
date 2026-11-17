# Shared by the desktop, the i5 laptop and the Orange Pi.
#
# Nix builds use every core at normal priority, so a long build or a store hash
# competes with whatever else the machine does: the desktop lags when opening a
# terminal, a server answers slowly. "batch" keeps builds at a lower CPU priority
# for the scheduler, and the idle I/O class lets everything else read the disk
# first.
{ ... }:
{
  nix.daemonCPUSchedPolicy = "batch";
  nix.daemonIOSchedClass = "idle";
}
