# This Makefile requires GNU Make or equivalent.
include os.mk

TARGET = trs80m13diag 
ASMFILES = $(TARGET:%=%.asm)
CIMFILES = $(TARGET:%=%.cim)
BDSFILES = $(TARGET:%=%.bds)
BINFILES = $(TARGET:%=%.bin)
HEXFILES = $(TARGET:%=%.hex)

all: $(BINFILES)
trs80m13diag.bin: inc/z80.mac inc/spt.mac inc/spt.asm inc/memtestmarch.asm inc/trs80con.asm inc/trs80music.asm Makefile os.mk

.PHONY: clean realclean
clean: 
	-$(RM) $(wildcard $(BDSFILES) $(TARGET:%=%.txt) $(TARGET:%=%.lst))

realclean: clean
	-$(RM) $(wildcard $(CIMFILES) $(BINFILES) $(HEXFILES))


$(BDSFILES): %.bds: %.bin


%.bin: %.asm Makefile
	@echo $(ZMAC) --zmac -m --od . --oo cim,bds,lst,hex $<
	@-$(SGR_YELLOW)
	@$(ZMAC) --zmac -m --od . --oo cim,bds,lst,hex $<
	@-$(SGR_RESET)
	$(REN) $(<:%.asm=%.cim) $@
	@-$(SGR_GREEN)
	@$(STAT) "%N: %z %Xz" $@
	@-$(SGR_RESET)


.PHONY: emu 
# emu: $(TARGET:%=%.emu)

MODEL = -m3
MEM = 32
SIMFLAGS = $(MODEL) -mem $(MEM)

emu: trs80m13diag.emu
emu1 emu1l emu3: emu

emu1: MODEL = -m1 -nlc -nld
emu1l: MODEL = -m1
emu3: MODEL = -m3

BREAKFLAGS=$(foreach brk,$(B),-b $(brk))

%.emu: %.bds %.bin
	$(EMU) -vol 20 -rand $(SIMFLAGS) $(BREAKFLAGS) -rom $(abspath $*.bin) -ls $(abspath $*.bds)

.DEFAULT: all
.PHONY: all
