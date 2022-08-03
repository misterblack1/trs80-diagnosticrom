

# TARGETS = system-test3.bin system-test3a.bin
# TARGET = z80-diag-rnd trs80diag system-test3a.asm
EMUTARGET = trs80testrom

ASMFILES = $(wildcard *.asm)
TARGET = $(ASMFILES:%.asm=%)

# all: $(patsubst %,%.cim,$(TARGET))

CIMFILES = $(TARGET:%=%.cim)
BDSFILES = $(TARGET:%=%.bds)


all: $(CIMFILES)

.PHONY: clean
clean: 
	 rm -f $(wildcard $(BDSFILES) $(CIMFILES) $(TARGET:%=%.txt) $(TARGET:%=%.lst))

trs80diag.cim: trs80diag.mac

$(BDSFILES): %.bds: %.cim

%.cim: %.asm Makefile
	zmac --zmac -m --od . --oo cim,bds,lst $<

# %.bin: %.asm Makefile
# 	z80asm --list=$*.txt --output=$*.bin $<

.PHONY: emu bademu
emu: $(TARGET:%=%.emu)
bademu: SIMFLAGS = -mem 32 
bademu: emu
emu1: SIMFLAGS = -m1 -nlc -nld -mem 16
emu1: emu
emu1l: SIMFLAGS = -m1 -mem 16
emu1l: emu
emu3: SIMFLAGS = -m3
emu3: emu

%.emu: %.bds %.cim
	osascript -e 'quit app "trs80gp"' ; sleep 1
	open -a trs80gp --args -vol 20 -rand $(SIMFLAGS) -rom $(abspath $*.cim) -ls $(abspath $*.bds)

# %.emu: %.bin
# 	-killall trs80gp
# 	open -a trs80gp --args -i "" -itime 9999999 -mem 32 -rom $(CURDIR)/$<
# 	# open -a trs80gp --args -i "" -itime 9999999 -rom $(CURDIR)/$<
