@echo off
echo Building the TRS-80 Diagnostic ROM...
echo Deleting intermediate files...
del *.cim
del *.bin
del *.hex
del *.lst
del *.bds
echo Assembling...
"C:\Program Files (x86)\zmac\zmac" --zmac -m --od . --oo cim,bds,lst,hex trs80m13diag.asm
ren trs80m13diag.cim trs80m13diag.bin
"C:\Program Files (x86)\zmac\zmac" --zmac -m --od . --oo cim,bds,lst,hex trs80m2diag.asm
ren trs80m2diag.cim trs80m2diag.bin
echo Done!