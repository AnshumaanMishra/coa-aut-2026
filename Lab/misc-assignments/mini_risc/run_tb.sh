#!/bin/bash
# Run from the project root (the directory containing inputs/ and data_path/).
# Usage: ./run_tb.sh [+quick] [+nomulu] [+verbose] [+vcd] [+trace] [+nrand=N] [+ncv=N]
mkdir -p build
iverilog -g2012 -s mini_risc_tb -o build/tb.vvp $(find . -name '*.v' -not -path './build/*') || exit 1
vvp build/tb.vvp "$@"
