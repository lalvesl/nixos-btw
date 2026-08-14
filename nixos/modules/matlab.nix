# Native (non-docker, non-web) MATLAB.
#
# MATLAB can't be packaged in nixpkgs: it's proprietary and needs a licensed
# account to download. nix-matlab doesn't ship MATLAB either — it provides
# buildFHSEnv wrappers that run an *imperatively installed* MATLAB tree from a
# normal FHS-looking environment, which is what its dynamically linked
# binaries expect.
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
  nix-matlab = inputs.nix-matlab.packages.x86_64-linux;
  fhsTargetPkgs = import "${inputs.nix-matlab}/common.nix";

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
  # environment as MATLAB itself.
  matlab-mpm = pkgs.buildFHSEnv {
    name = "matlab-mpm";
    targetPkgs = fhsTargetPkgs;
    runScript = pkgs.writeScript "matlab-mpm-runner" ''
      exec ${mpmBin} "$@"
    '';
    meta = {
      description = "MathWorks Package Manager (mpm), wrapped in MATLAB's FHS env";
    };
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

  # Upstream nix-matlab is archived and its python package no longer evaluates
  # against current nixpkgs (buildPythonPackage now demands an explicit
  # format/build-system), so it's redefined here from the same sources instead
  # of taken from the flake.
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

  matlab-python-shell = pkgs.buildFHSEnv {
    name = "matlab-python-shell";
    targetPkgs = fhsTargetPkgs;
    runScript = pkgs.writeScript "matlab-python-shell-runner" ''
      export QT_QPA_PLATFORM=xcb
      if [[ -f ~/.config/matlab/nix.sh ]]; then
        source ~/.config/matlab/nix.sh
      else
        echo "nix-matlab-error: Did not find ~/.config/matlab/nix.sh" >&2
        exit 1
      fi
      if [[ ! -d "$INSTALL_DIR" ]]; then
        echo "nix-matlab-error: INSTALL_DIR $INSTALL_DIR isn't a directory" >&2
        exit 2
      fi
      export MATLAB_INSTALL_DIR="$INSTALL_DIR"
      unset INSTALL_DIR
      export PYTHONPATH=${matlab-python-package}/${pkgs.python3.sitePackages}
      exec python "$@"
    '';
    meta = {
      description = "Python shell with MATLAB's engine importable";
    };
  };
in
{
  nixpkgs.overlays = [ inputs.nix-matlab.overlay ];

  environment.systemPackages = [
    nix-matlab.matlab # the GUI/CLI launcher
    nix-matlab.matlab-shell # FHS shell used to run the installer
    nix-matlab.matlab-mlint # code checker
    nix-matlab.matlab-mex # MEX builder
    matlab-mpm # raw mpm, for one-off product operations
    matlab-install-products # mpm preloaded with the product list above
  ]
  ++ lib.optionals enablePythonEngine [
    matlab-python-package
    matlab-python-shell
  ];
}
