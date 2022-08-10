# This Makefile requires GNU Make or equivalent.
include os.mk

TARGET = trs80testrom
ASMFILES = $(TARGET:%=%.asm)
CIMFILES = $(TARGET:%=%.cim)
BDSFILES = $(TARGET:%=%.bds)
BINFILES = $(TARGET:%=%.bin)
HEXFILES = $(TARGET:%=%.hex)

trs80testrom.bin: inc/trs80diag.mac inc/memtest-march.asm inc/trs80con.asm inc/trs80music.asm Makefile

.PHONY: clean realclean
clean: 
	-$(RM) $(wildcard $(BDSFILES) $(TARGET:%=%.txt) $(TARGET:%=%.lst))

realclean: clean
	-$(RM) $(wildcard $(CIMFILES) $(BINFILES) $(HEXFILES))


$(BDSFILES): %.bds: %.bin


%.bin: %.asm Makefile os.mk
	@echo $(ZMAC) --zmac -m --od . --oo cim,bds,lst,hex $<
	@-$(SGR_YELLOW)
	@$(ZMAC) --zmac -m --od . --oo cim,bds,lst,hex $<
	@-$(SGR_RESET)
	$(REN) $(<:%.asm=%.cim) $@


.PHONY: emu 
emu: $(TARGET:%=%.emu)
emu1: SIMFLAGS = -m1 -nlc -nld -mem 16
emu1: emu
emu1-4: SIMFLAGS = -m1 -nlc -nld -mem 4
emu1-4: emu
emu1-48: SIMFLAGS = -m1 -nlc -nld -mem 48
emu1-48: emu
emu1-3: SIMFLAGS = -m1 -nlc -nld -mem 3
emu1-3: emu

emu1l: SIMFLAGS = -m1 -mem 16
emu1l: emu
emu1l-4: SIMFLAGS = -m1 -mem 4
emu1l-4: emu
emu1l-48: SIMFLAGS = -m1 -mem 48
emu1l-48: emu
emu1l-3: SIMFLAGS = -m1 -mem 3
emu1l-3: emu

emu3: SIMFLAGS = -m3
emu3: emu
emu3-4: SIMFLAGS = -m3 -mem 4
emu3-4: emu
emu3-3: SIMFLAGS = -m3 -mem 3
emu3-3: emu

BREAKFLAGS=$(foreach brk,$(BREAK),-b $(brk))

%.emu: %.bds %.bin
	# @osascript -e 'quit app "trs80gp"' ; sleep 0.25
	$(EMU) -vol 20 -rand $(SIMFLAGS) $(BREAKFLAGS) -rom $(abspath $*.bin) -ls $(abspath $*.bds)

.DEFAULT: all
.PHONY: all
all: $(BINFILES)
