# Native (non-docker, non-web) MATLAB.
#
# MATLAB can't be packaged in nixpkgs: it's proprietary and needs a licensed
# account to download. nix-matlab doesn't ship MATLAB either — it provides
# buildFHSEnv wrappers that run an *imperatively installed* MATLAB tree from a
# normal FHS-looking environment, which is what its dynamically linked
# binaries expect.
#
# Those wrappers are rebuilt here instead of taken from the flake's outputs;
# see `fhsTargetPkgs` below for why. Only data files — the icons, install.adoc
# and the python patch — still come out of the input.
#
# First-time setup, via mpm (no GUI installer, no MathWorks login to download):
#
#   1. matlab-install-products
#      Installs MATLAB plus the toolboxes listed in `matlabProducts` below into
#      ~/.local/share/matlab/installation (the path declared in
#      ./home/matlab.nix — keep the two in sync). Takes a while; it's tens of GB.
#   2. matlab
#      Sign in / activate on first launch, as on any other distro.
#
# Adding toolboxes later: add them to `matlabProducts` and re-run
# `matlab-install-products` — mpm installs the missing ones in place.
#
# Alternative, if you'd rather use MathWorks' graphical installer: download the
# installer zip from https://www.mathworks.com/mwaccount/, unzip it, then run
# `matlab-shell` and `./install` from inside that FHS shell, pointing it at the
# same directory.
#
# Either way `matlab` (CLI + desktop launcher), `mlint` and `mex` then work
# system-wide.
{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # MATLAB's FHS dependency list, vendored from nix-matlab's common.nix.
  #
  # Importing that file still works, but it reaches the X11 libraries through
  # `pkgs.xorg.*`, a set nixpkgs deprecated in January 2026, so every
  # evaluation printed 21 rename warnings. Vendoring the list only fixes half
  # of that: the flake's own wrappers evaluate the same file against their own
  # nixpkgs, which no overlay here can reach, so they are rebuilt below from
  # this list instead. Upstream is archived, so there is no fix to wait for.
  #
  # The packages are the ones the aliases resolved to -- `xorg.libX11` *is*
  # `libx11` -- so the environment MATLAB sees is unchanged.
  #
  # Upstream derived the list from MathWorks' official R2020a container image
  # (https://github.com/mathworks-ref-arch/container-images) and extended it
  # per release; its per-release notes are kept.
  fhsTargetPkgs =
    pkgs: with pkgs; [
      cacert
      alsa-lib # libasound2
      atk
      glib
      glibc
      cairo
      cups
      dbus
      fontconfig
      gdk-pixbuf
      gst_all_1.gst-plugins-base
      gst_all_1.gstreamer
      gtk3
      nspr
      nss
      pam
      pango
      python3
      libselinux
      libsndfile
      glibcLocales
      procps
      unzip
      zlib
      linux-pam

      # These packages are needed since 2021b version
      gtk2
      at-spi2-atk
      at-spi2-core
      libdrm

      # Required by Simulink
      mesa

      gcc
      gfortran

      # nixos specific
      udev
      jre
      ncurses # Needed for CLI

      # Keyboard input may not work in simulink otherwise
      libxkbcommon
      xkeyboard_config

      # Needed since 2022a
      libglvnd

      # Needed since 2022b
      libuuid
      libxcrypt
      libxcrypt-legacy

      # Needed since 2024
      libgbm

      # X11. Spelled xorg.libSM, xorg.libX11, ... upstream, before that set was
      # deprecated.
      libsm
      libx11
      libxcb
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxft
      libxi
      libxinerama
      libxrandr
      libxrender
      libxt
      libxtst
      libxxf86vm

      # Needed since 2025
      libice
    ];

  # Every wrapper starts by locating the imperative installation. matlab-shell
  # passes errorOut = false: it is the thing you run *before* MATLAB exists, so
  # a missing nix.sh there is not a failure.
  runScriptPrefix =
    {
      errorOut ? true,
    }:
    ''
      # Needed for simulink even on wayland systems
      export QT_QPA_PLATFORM=xcb
      # Where MATLAB was installed imperatively; written by ./home/matlab.nix.
      if [[ -f ~/.config/matlab/nix.sh ]]; then
        source ~/.config/matlab/nix.sh
    ''
    + lib.optionalString errorOut ''
      else
        echo "nix-matlab-error: Did not find ~/.config/matlab/nix.sh" >&2
        exit 1
      fi
      if [[ ! -d "$INSTALL_DIR" ]]; then
        echo "nix-matlab-error: INSTALL_DIR $INSTALL_DIR isn't a directory" >&2
        exit 2
    ''
    + ''
      fi
    '';

  # The entry points differ only in the script they run, so the FHS environment
  # itself is described once.
  matlabWrapper =
    {
      name,
      description,
      script,
      extraInstallCommands ? "",
    }:
    pkgs.buildFHSEnv {
      inherit name extraInstallCommands;
      targetPkgs = fhsTargetPkgs;
      runScript = pkgs.writeScript "${name}-runner" script;
      meta = {
        inherit description;
        homepage = "https://www.mathworks.com/";
        # nix-matlab's license, not MATLAB's.
        license = lib.licenses.mit;
        platforms = lib.platforms.linux;
      };
    };

  # @out@ is substituted at install time because the desktop file has to point
  # at the wrapper that embeds it.
  desktopItem = pkgs.makeDesktopItem {
    desktopName = "Matlab";
    name = "matlab";
    # -desktop is needed, see
    # https://www.mathworks.com/matlabcentral/answers/20-how-do-i-make-a-desktop-launcher-for-matlab-in-linux#answer_25
    exec = "@out@/bin/matlab -desktop %F";
    icon = "matlab";
    # Most of the following are copied from octave's desktop launcher
    categories = [
      "Utility"
      "TextEditor"
      "Development"
      "IDE"
    ];
    mimeTypes = [
      "text/x-octave"
      "text/x-matlab"
    ];
    keywords = [
      "science"
      "math"
      "matrix"
      "numerical computation"
      "plotting"
    ];
  };

  matlab = matlabWrapper {
    name = "matlab";
    description = "Matlab itself - the GUI launcher";
    script = (runScriptPrefix { }) + ''
      # Needed in order to run and load NixOS' executables and shared objects
      # installed to the FHS environment. Forces matlab to not use their
      # potentially outdated and incompatible libstdc++.
      exec env \
        LD_PRELOAD=/lib/libstdc++.so \
        LD_LIBRARY_PATH=/usr/lib/xorg/modules/dri/ \
        $INSTALL_DIR/bin/matlab "$@"
    '';
    extraInstallCommands = ''
      install -Dm644 ${desktopItem}/share/applications/matlab.desktop \
        $out/share/applications/matlab.desktop
      substituteInPlace $out/share/applications/matlab.desktop \
        --replace-fail "@out@" ${builtins.placeholder "out"}
      for size in 64x64 256x256 512x512; do
        install -Dm644 ${inputs.nix-matlab}/icons/hicolor/$size/matlab.png \
          $out/share/icons/hicolor/$size/apps/matlab.png
      done
    '';
  };

  matlab-shell = matlabWrapper {
    name = "matlab-shell";
    description = "A bash shell from which you can install matlab or launch matlab from CLI";
    script =
      (runScriptPrefix {
        # If the user hasn't setup a ~/.config/matlab/nix.sh file yet, don't
        # yell at them that it's missing
        errorOut = false;
      })
      + ''
        cat <<EOF
        ============================
        welcome to nix-matlab shell!

        To install matlab:
        ${lib.strings.escape [ "`" "'" "\"" "$" ] (builtins.readFile "${inputs.nix-matlab}/install.adoc")}

        4. Finish the installation, and exit the shell (with \`exit\`).
        5. Follow the rest of the instructions in the README to make matlab
           executable available anywhere on your system.
        ============================
        EOF
        exec bash
      '';
  };

  matlab-mlint = matlabWrapper {
    name = "mlint";
    description = "Check MATLAB code files for possible problems";
    script = (runScriptPrefix { }) + ''
      exec $INSTALL_DIR/bin/glnxa64/mlint "$@"
    '';
  };

  matlab-mex = matlabWrapper {
    name = "mex";
    description = "Build MEX function or engine application";
    script = (runScriptPrefix { }) + ''
      exec $INSTALL_DIR/bin/glnxa64/mex "$@"
    '';
  };

  # MathWorks Package Manager: installs MATLAB and toolboxes from the CLI, no
  # GUI installer and no login needed to download (licensing still happens on
  # first launch of `matlab`).
  #
  # MathWorks reserves this URL for the newest mpm and rebuilds it in place, so
  # the hash goes stale every few months. When the fetch fails, refresh it:
  #   nix store prefetch-file --executable https://www.mathworks.com/mpm/glnxa64/mpm
  mpmBin = pkgs.fetchurl {
    url = "https://www.mathworks.com/mpm/glnxa64/mpm";
    hash = "sha256-nC7ZNTKUFuvnPeOEreNtylCwkFJATyRKRNfTXzXEVLc=";
    executable = true;
  };

  # Release to install/extend — change this one line to switch versions, then
  # re-run `matlab-install-products`. Toolboxes must match the release of the
  # MATLAB they're installed into, so a different release means a fresh
  # INSTALL_DIR (or wipe the old one first). The product list below was checked
  # against R2026a and R2025b.
  matlabRelease = "R2026a";

  # Toolboxes installed by `matlab-install-products`. Control + electrical
  # engineering set; add or drop lines and re-run the command.
  matlabProducts = [
    "MATLAB"
    "Simulink"
    "Stateflow"

    # Control
    "Control_System_Toolbox"
    "Simulink_Control_Design"
    "System_Identification_Toolbox"
    "Robust_Control_Toolbox"
    "Model_Predictive_Control_Toolbox"
    "Simulink_Design_Optimization"

    # Electrical / physical modeling
    "Simscape"
    "Simscape_Electrical"
    "Motor_Control_Blockset"
    "SimEvents"

    # Signals & math the two above lean on
    "Signal_Processing_Toolbox"
    "DSP_System_Toolbox"
    "Symbolic_Math_Toolbox"
    "Optimization_Toolbox"
    "Curve_Fitting_Toolbox"
    "Statistics_and_Machine_Learning_Toolbox"

    # Hardware in the loop
    "Instrument_Control_Toolbox"
    # Data_Acquisition_Toolbox is deliberately absent: mpm rejects it as
    # "not supported on the specified platforms" — it's Windows-only.
  ];

  # mpm is a dynamically linked MathWorks binary, so it needs the same FHS
  # environment as MATLAB itself. No prefix: it is what creates INSTALL_DIR.
  matlab-mpm = matlabWrapper {
    name = "matlab-mpm";
    description = "MathWorks Package Manager (mpm), wrapped in MATLAB's FHS env";
    script = ''
      exec ${mpmBin} "$@"
    '';
  };

  # Installs the product list above into the same INSTALL_DIR the wrappers read.
  # Re-running it after editing `matlabProducts` adds the new toolboxes in
  # place; extra arguments are passed through to mpm.
  matlab-install-products = pkgs.writeShellScriptBin "matlab-install-products" ''
    set -euo pipefail
    if [[ ! -f ~/.config/matlab/nix.sh ]]; then
      echo "matlab: no ~/.config/matlab/nix.sh — is nixos/modules/home/matlab.nix active?" >&2
      exit 1
    fi
    source ~/.config/matlab/nix.sh
    mkdir -p "$INSTALL_DIR"
    exec ${matlab-mpm}/bin/matlab-mpm install \
      --release=${matlabRelease} \
      --destination="$INSTALL_DIR" \
      --products ${lib.concatStringsSep " " matlabProducts} \
      "$@"
  '';

  # MATLAB's engine for Python. Off by default: unlike the wrappers above it
  # can't be built from the flake alone — it needs the engine sources copied
  # out of your own MATLAB installation into the store first (see
  # `pythonSrcSha256` below), so leaving it on would fail every rebuild done
  # before that one-time step.
  #
  # To enable:
  #   1. source ~/.config/matlab/nix.sh
  #   2. nix store add-path $INSTALL_DIR/extern/engines/python \
  #        --name 'matlab-python-src'
  #   3. nix-store --query --hash \
  #        $(nix store add-path $INSTALL_DIR/extern/engines/python \
  #          --name 'matlab-python-src')
  #      Put that hash in `pythonSrcSha256` and flip `enablePythonEngine`.
  # Then `matlab-python-shell` gives you a python REPL with `import matlab.engine`.
  enablePythonEngine = false;
  pythonSrcSha256 = "";

  # Upstream's python package no longer evaluates against current nixpkgs
  # (buildPythonPackage now demands an explicit format/build-system), so it's
  # redefined here from the same sources instead of taken from the flake.
  matlab-python-package = pkgs.python3.pkgs.buildPythonPackage {
    pname = "matlab-python-package";
    version = "unstable";
    pyproject = true;
    build-system = [ pkgs.python3.pkgs.setuptools ];

    src = pkgs.requireFile {
      name = "matlab-python-src";
      sha256 = pythonSrcSha256;
      hashMode = "recursive";
      message = ''
        Run, with MATLAB already installed:

          source ~/.config/matlab/nix.sh
          nix store add-path $INSTALL_DIR/extern/engines/python --name 'matlab-python-src'

        and make sure `pythonSrcSha256` in nixos/modules/matlab.nix matches the
        hash it reports.
      '';
    };
    unpackCmd = ''
      cp -r $curSrc/ matlab-python-src
      sourceRoot=$PWD/matlab-python-src
    '';
    # MATLAB's setup.py writes an _arch.txt next to the installed package to
    # record where MATLAB lives; the patch makes __init__.py read
    # $MATLAB_INSTALL_DIR instead, which is what the FHS wrappers export.
    patches = [ "${inputs.nix-matlab}/python-no_arch.txt-file.patch" ];

    meta = {
      description = "MATLAB engine for Python, patched for a Nix installation";
      homepage = "https://www.mathworks.com/help/matlab/matlab-engine-for-python.html";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };

  matlab-python-shell = matlabWrapper {
    name = "matlab-python-shell";
    description = "Python shell with MATLAB's engine importable";
    script = (runScriptPrefix { }) + ''
      export MATLAB_INSTALL_DIR="$INSTALL_DIR"
      unset INSTALL_DIR
      export PYTHONPATH=${matlab-python-package}/${pkgs.python3.sitePackages}
      exec python "$@"
    '';
  };
in
{
  environment.systemPackages = [
    matlab # the GUI/CLI launcher
    matlab-shell # FHS shell used to run the installer
    matlab-mlint # code checker
    matlab-mex # MEX builder
    matlab-mpm # raw mpm, for one-off product operations
    matlab-install-products # mpm preloaded with the product list above
  ]
  ++ lib.optionals enablePythonEngine [
    matlab-python-package
    matlab-python-shell
  ];
}
