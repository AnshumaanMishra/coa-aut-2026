# Makefile for bram_ram_rom_practice simulation (iverilog + vvp + gtkwave)
#
# Layout assumed:
#   ./bram_ram_rom_practice.v
#   ./bram_ram_rom_practice_tb.v
#   ./memory_sim/address_rom.v
#   ./memory_sim/data_ram.v
#   ./memory_sim/program.mem
#   ./memory_sim/data_ram.mem

MEMDIR   = memory_sim
TB       = bram_ram_rom_practice_tb.v
TOP      = bram_ram_rom_practice.v
SRCS     = $(TB) $(TOP) $(MEMDIR)/address_rom.v $(MEMDIR)/data_ram.v

MEMFILES = program.mem data_ram.mem

VVP_OUT  = sim.vvp
VCD_OUT  = bram_ram_rom_practice_tb.vcd

.PHONY: all compile run wave clean

all: run

# $readmemh in address_rom.v / data_ram.v is called with a bare filename
# ("program.mem", "data_ram.mem"), so it resolves relative to the *simulation's*
# working directory, not to memory_sim/. Copy the .mem files up before running.
$(MEMFILES): $(MEMDIR)/program.mem $(MEMDIR)/data_ram.mem
	cp $(MEMDIR)/program.mem .
	cp $(MEMDIR)/data_ram.mem .

compile: $(SRCS)
	iverilog -g2012 -o $(VVP_OUT) $(SRCS)

run: compile $(MEMFILES)
	vvp $(VVP_OUT)

wave: run
	gtkwave $(VCD_OUT) &

clean:
	rm -f $(VVP_OUT) $(VCD_OUT) $(MEMFILES)
