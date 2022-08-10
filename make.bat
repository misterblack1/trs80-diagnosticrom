@echo off
echo Building the trs80testrom.asm...
echo Deleting build files...
del *.cim
del *.bin
del *.hex
del *.lst
del *.bds
echo Assembling...
"C:\Program Files (x86)\zmac\zmac" --zmac --od . --oo cim,bds,lst,hex trs80testrom.asm
ren trs80testrom.cim trs80testrom.bin
echo Done!