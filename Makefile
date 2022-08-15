# This Makefile requires GNU Make or equivalent.
include os.mk

TARGET = trs80testrom-spt trs80m2test trs80testrom 
ASMFILES = $(TARGET:%=%.asm)
CIMFILES = $(TARGET:%=%.cim)
BDSFILES = $(TARGET:%=%.bds)
BINFILES = $(TARGET:%=%.bin)
HEXFILES = $(TARGET:%=%.hex)

all: $(BINFILES)
trs80testrom.bin: inc/trs80diag.mac inc/memtest-march.asm inc/trs80con.asm inc/trs80music.asm Makefile os.mk
trs80m2test.bin: inc/trs80diag.mac inc/memtest-march.asm Makefile os.mk
trs80testrom-spt.bin: inc/trs80diag.mac inc/memtest-march-spt.asm inc/trs80con-spt.asm inc/trs80music-spt.asm inc/spthread.mac inc/spthread.asm Makefile os.mk

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

emuspt: trs80testrom-spt.emu
emuspt1 emuspt1l: emuspt

emuspt1: MODEL = -m1 -nlc -nld

# emuspt: SIMFLAGS = -m1 -nlc -nld -mem 32
# emuspt3: SIMFLAGS = -m3 -mem 32
# emuspt3: trs80testrom-spt.emu
# emuspt1: SIMFLAGS = -m1 -nlc -nld -mem 32
# emuspt1: trs80testrom-spt.emu

emu1: trs80testrom.emu
emu1-4: SIMFLAGS = -m1 -nlc -nld -mem 4
emu1-4: emu1
emu1-16: SIMFLAGS = -m1 -nlc -nld -mem 16
emu1-16: emu1
emu1-48: SIMFLAGS = -m1 -nlc -nld -mem 48
emu1-48: emu1
emu1-3: SIMFLAGS = -m1 -nlc -nld -mem 3
emu1-3: emu1

emu1l: SIMFLAGS = -m1 -mem 16
emu1l: trs80testrom.emu
emu1l-4: SIMFLAGS = -m1 -mem 4
emu1l-4: emu1l
emu1l-48: SIMFLAGS = -m1 -mem 48
emu1l-48: emu1l
emu1l-3: SIMFLAGS = -m1 -mem 3
emu1l-3: emu1l

emu3: SIMFLAGS = -m3
emu3: trs80testrom.emu
emu3-4: SIMFLAGS = -m3 -mem 4
emu3-4: emu3
emu3-3: SIMFLAGS = -m3 -mem 3
emu3-3: emu3

.PHONY: emu2
emu2: SIMFLAGS = -m2
emu2: trs80m2test.emu

BREAKFLAGS=$(foreach brk,$(BREAK),-b $(brk))

%.emu: %.bds %.bin
	$(EMU) -vol 20 -rand $(SIMFLAGS) $(BREAKFLAGS) -rom $(abspath $*.bin) -ls $(abspath $*.bds)

.DEFAULT: all
.PHONY: all
