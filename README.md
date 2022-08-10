# TRS-80 Diagnostic ROMs

![Normal Operation](https://github.com/misterblack1/trs80-diagnosticrom/blob/main/documentation/Normal%20Operation%2016K%20Model%203.jpg?raw=true)

Currently, what exiats is a release for the:

TRS-80 Model 1 and 3

The VRAM test detects if the machine is a 7-bit VRAM Model 1 by testing the VRAM. If bit 6 (data line 6) comes back as bad, it assumes it's a model 1. If you have a Model 3 or a 8-bit VRAM model 1 and it says it's using the stack in DRAM, then bit 6 of the VRAM has a problem and you must fix that. 

When bad bits are detected in VRAM or DRAM, you will hear a beep code telling you which bit is bad. The beeping goes from Bit 7 (MSB) to Bit 0 (LSB.) So if you hear, high high high low high high high high, then the bad bit is BIT 4 (of 7). You will not hear a VRAM beep code for a problem in bit-6 because it assumes it is a Model 1. (See above.)

4K DRAM machinse can only ever have 4K of RAM, so only the first 4K of ram is tested and no more.

You **must** have a working connection on JP2A and JP2B to run this diagnostic. Both the cassette port (for audio output) but more importantly the video output is across this interconnect. If you have a video problem but at least bits 0 and bit 1 are connected on the interconnect, audio output should work to help you know the system is working. On the Model 3, the cassette port output is the pin closest to the keyboard connector. (Connector J3)

You do not need any DRAM installed in the machine for the diagnostic to run. If you have good working VRAM but no working DRAM, you should see it trying to test the DRAM, but all banks will come back as bad. Keep in mand a stuck or bad DRAM bus transciever can trash the entire bus, causing the VRAM test to also fail.

You do not need the keyboard connected for the system to run the diagnostic. The keyboard is not used during the test at all.

The diagnostic ROM _must_ be installed into U104 on the TRS-80 Model 3. You must use a 2364 to 27XXX adapter. The one I used is made for 27128, but it works just fine with 2764 and more importantly 28B64C (EEPROMs.) You can also use this same adapter in U105 (for testing replacment of that ROM.) You can use a normal 2716 in U106 if you need to test replacing that ROM.

You do not need to have any ROM installed in U105 or U106 during the test. A bad ROM in one of those sockets could cause the computer to not work.

You do not need the interconnect between JP1A and JP1B. This is only to connect the floppy and serial board. The system will operate fine without the interconnect, but you will not be able to use the floppy or serial port. 


