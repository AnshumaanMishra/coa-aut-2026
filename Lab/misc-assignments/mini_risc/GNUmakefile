# MiniRISC project Makefile
# DISCLAIMER: AI GENERATED
# Compiles every Verilog source in the project into a single VVP image.
# The memory models use bare filenames in $readmemh(), so the sim target
# runs vvp from the build directory where the memory files are linked.

IVERILOG ?= iverilog
VVP      ?= vvp

BUILD_DIR := build
VVP_FILE  := $(BUILD_DIR)/mini_risc.vvp

# Every .v file anywhere under the project root.
VERILOG_SOURCES := $(shell find . -type f -name '*.v' -print)

# $readmemh() filenames used by memory_sim/address_rom.v and data_ram.v.
MEM_FILES := $(BUILD_DIR)/program.mem $(BUILD_DIR)/data_ram.mem

.PHONY: all compile sim clean

all: compile

compile: $(VVP_FILE)

# -g2012 is accepted by Icarus for this Verilog/SystemVerilog-compatible code.
# -Wall enables useful warnings.
# -s mini_risc explicitly selects the processor as the simulation top module.
$(VVP_FILE): $(VERILOG_SOURCES)
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s mini_risc -o $@ $(VERILOG_SOURCES)

# Keep the memory images out of the source tree while making the bare
# filenames used by $readmemh() resolve when running from $(BUILD_DIR).
$(BUILD_DIR)/program.mem: memory_sim/program.mem
	@mkdir -p $(BUILD_DIR)
	ln -sf ../$< $@

$(BUILD_DIR)/data_ram.mem: memory_sim/data_ram.mem
	@mkdir -p $(BUILD_DIR)
	ln -sf ../$< $@

# Compile and execute the generated VVP image.
# Note: the current project has no testbench/clock stimulus, so this target
# only executes the design; add a testbench to actually run a timed simulation.
sim: compile $(MEM_FILES)
	cd $(BUILD_DIR) && $(VVP) mini_risc.vvp

clean:
	rm -rf $(BUILD_DIR)
