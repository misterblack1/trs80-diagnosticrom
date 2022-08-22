# This Makefile requires GNU Make or equivalent.
include os.mk

TARGET = trs80m2diag trs80m13diag 
ASMFILES = $(TARGET:%=%.asm)
CIMFILES = $(TARGET:%=%.cim)
BDSFILES = $(TARGET:%=%.bds)
BINFILES = $(TARGET:%=%.bin)
HEXFILES = $(TARGET:%=%.hex)

all: $(BINFILES)
trs80m13diag.bin: inc/z80.mac inc/spt.mac inc/spt.asm inc/memtestmarch.asm inc/trs80m13con.asm inc/trs80music.asm Makefile os.mk
trs80m2diag.bin: inc/z80.mac inc/spt.mac inc/spt.asm inc/memtestmarch.asm inc/trs80m2con.asm inc/trs80m2music.asm Makefile os.mk

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

MODEL = -m3
# MEM = 32
EMUFLAGS = $(MODEL) $(foreach m,$(MEM),-mem $(m))

emu emu1 emu1l emu3 emu4: trs80m13diag.emu
emu2 emu12 emu16 emu6k: trs80m2diag.emu

emu1: MODEL = -m1 -nlc -nld
emu1l: MODEL = -m1
emu3: MODEL = -m3
emu2: MODEL = -m2
emu12: MODEL = -m12
emu16: MODEL = -m16
emu6k: MODEL = -m6000
emu4: MODEL = -m4
emu4p: MODEL = -m4p
emu4d: MODEL = -m4d


BREAKFLAGS=$(foreach brk,$(B),-b $(brk))

%.emu: %.bds %.bin
	$(EMU) -ee -vol 20 -rand $(EMUFLAGS) $(BREAKFLAGS) -rom $*.bin -ls $*.bds $(E)

.DEFAULT: all
.PHONY: all
