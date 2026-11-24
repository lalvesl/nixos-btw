{ pkgs, ... }:
let
  noTurbo = "/sys/devices/system/cpu/intel_pstate/no_turbo";

  # Writes 0 to no_turbo. Where the firmware really blocks turbo, or the CPU has
  # no intel_pstate, the write fails or the file is missing, and that is fine.
  enableTurbo = pkgs.writeShellScript "enable-turbo" ''
    if [ -w ${noTurbo} ]; then
      echo 0 > ${noTurbo} 2>/dev/null || true
    fi
  '';
in
{
  # Booting on battery (or on a low one) makes the firmware turn turbo off, and
  # intel_pstate then reports no_turbo=1. Plugging the charger in lets the
  # firmware allow turbo again, but the kernel keeps the stale 1 until reboot:
  # the clock stays at the base frequency (2.3 GHz on the i5-8300H) instead of
  # the 4.0 GHz it can reach. Clear it whenever the charger comes in, and once
  # at boot for a machine that starts already plugged in.
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="${enableTurbo}"
  '';

  systemd.services.enable-turbo = {
    description = "Let the CPU use turbo again";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = enableTurbo;
    };
  };

  # services.thermald.enable = false;

  # services.intel-undervolt = {
  #   enable = true;
  #   config = [
  #     { domain = "cpu";       value = -80; }
  #     { domain = "gpu";       value = -40; }
  #     { domain = "cpu-cache"; value = -80; }
  #   ];
  # };
}
