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

# ---- memory init files (readmemh paths in address_rom.v / data_ram.v are
# relative to this directory). Always (re)generate them so the test program
# is the one in the ROM; any existing file is backed up once as *.bak.
mkdir -p inputs
[ -f inputs/program.mem ] && [ ! -f inputs/program.mem.bak ] && cp inputs/program.mem inputs/program.mem.bak
cat > inputs/program.mem << 'MEM'
C0200005
C0400007
80611010
80811011
80A11018
80C20820
80E40808
C0000063
81200810
81400010
C161FFFD
E1840001
FC000000
00000000
00000000
00000000
MEM
if [ ! -f inputs/data_ram.mem ]; then
  for _ in $(seq 16); do echo 00000000; done > inputs/data_ram.mem
fi
echo "Using $(pwd)/inputs/program.mem"

# all .v files, recursively (other unit testbenches are left out so only
# tb_minirisc_datapath is the top; $readmemh paths like inputs/program.mem
# are relative to this directory, where the simulation is run)
# (skip build dir and Vivado project output dirs)
mapfile -t SRCS < <(find . -type f -name '*.v' \
    -not -path "./$BUILD/*" -not -path '*/.Xil/*' -not -path '*.sim/*' \
    -not -path '*.runs/*' -not -path './tb_all/*' -not -name '*_tb.v' | sort)

if [ ${#SRCS[@]} -eq 0 ]; then
  echo "No .v files found." >&2
  exit 1
fi
echo "Sources (${#SRCS[@]}):"
printf '  %s\n' "${SRCS[@]}"

case "$TOOL" in
  iverilog)
    iverilog -g2012 -Wno-timescale -s "$TOP" -o "$BUILD/sim.vvp" "${SRCS[@]}"
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
