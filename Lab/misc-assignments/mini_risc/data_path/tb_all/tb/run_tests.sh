#!/bin/bash
# run from the project root (the folder that has data_path/ in it):
#   ./tb/run_tests.sh              runs every bench
#   ./tb/run_tests.sh tb_alu       runs one
mkdir -p build
if [ $# -gt 0 ]; then list="$@"; else list=$(ls tb/tb_*.v | xargs -n1 basename | sed 's/\.v$//'); fi

for t in $list; do
  iverilog -g2012 -s $t -o build/$t.vvp $(find data_path -name '*.v') tb/$t.v || { echo "$t: compile error"; continue; }
  vvp build/$t.vvp | grep -v '\$finish'
done
