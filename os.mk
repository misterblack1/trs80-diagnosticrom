# this file attempts to give basic OS independence to the make process.
# It depends on GNU Make (or compatible)


ifeq ($(OS),Windows_NT)
# buiding on Windows currently untested
    RM = cmd //C del //Q //F
    RRM = cmd //C rmdir //Q //S
	REN = ren
	ZMAC = "C:\Program Files (x86)\zmac\zmac"
	SGR_YELLOW =
	SGR_GREEN =
	SGR_RESET =
	STAT = cmd //C rem
else
    RRM = $(RM) -r
	REN = mv
	ZMAC = zmac
	SGR_YELLOW = tput sgr0 ; tput setaf 3 ; tput bold
	SGR_GREEN = tput setaf 2; tput bold 
	SGR_RESET = tput sgr0
	EMU = trs80gp

    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Darwin)
		STAT = stat -f
	else
		STAT = stat -c
    endif
    ifeq ($(UNAME_S),Linux)
    endif
endif