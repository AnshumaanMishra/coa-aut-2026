#!/usr/bin/env bash
# Usage: ./run.sh [iverilog|xsim] [--wave]
#   iverilog (default): compile + run with Icarus Verilog, optional GTKWave
#   xsim              : compile + run with Vivado xvlog/xelab/xsim
# Recursively collects every .v file below the current directory.
set -euo pipefail

TOP=tb_minirisc_datapath
TOOL=${1:-iverilog}
WAVE=${2:-}
BUILD=build

cd "$(dirname "$0")"
mkdir -p "$BUILD"

# all .v files, recursively (skip build dir and Vivado project output dirs)
mapfile -t SRCS < <(find . -type f -name '*.v' \
    -not -path "./$BUILD/*" -not -path '*/.Xil/*' -not -path '*.sim/*' \
    -not -path '*.runs/*' | sort)

if [ ${#SRCS[@]} -eq 0 ]; then
  echo "No .v files found." >&2
  exit 1
fi
echo "Sources (${#SRCS[@]}):"
printf '  %s\n' "${SRCS[@]}"

case "$TOOL" in
  iverilog)
    iverilog -g2005 -Wall -s "$TOP" -o "$BUILD/sim.vvp" "${SRCS[@]}"
    vvp "$BUILD/sim.vvp"
    [ "$WAVE" = "--wave" ] && gtkwave "$TOP.vcd" &
    ;;
  xsim)
    cd "$BUILD"
    # paths are now relative to build/, so prefix with ../
    xvlog $(printf '../%s ' "${SRCS[@]}")
    xelab -debug typical -L unisims_ver -L secureip "$TOP" -s sim
    if [ "$WAVE" = "--wave" ]; then xsim sim -gui; else xsim sim -runall; fi
    ;;
  *)
    echo "Unknown tool '$TOOL' (use iverilog or xsim)" >&2
    exit 1
    ;;
esac
