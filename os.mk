# this file attempts to give basic OS independence to the make process.
# It depends on GNU Make (or compatible)


ifeq ($(OS),Windows_NT)
# buiding on Windows currently untested
    RM = cmd //C del //Q //F
    RRM = cmd //C rmdir //Q //S
	REN = ren
	ZMAC = "C:\Program Files (x86)\zmac\zmac"
	SGR_COMMAND = 
	SGR_OUTPUT =
	SGR_SIZE =
	SGR_RESET =
	STAT = cmd //C rem
	CECHO =
else
    RRM = $(RM) -r
	REN = mv
	ZMAC = zmac
	SGR_COMMAND := `tput sgr0 ; tput setaf 7 ; tput setab 4 ; tput bold`
	SGR_OUTPUT := `tput sgr0 ; tput setaf 3 ; tput bold`
	SGR_SIZE := `tput setaf 2; tput bold`
	SGR_RESET := `tput sgr0`
	EMU = trs80gp
	CECHO = echo
	CECHON = printf "%s"

    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Darwin)
		STAT = stat -f
	else
		STAT = stat -c
    endif
    ifeq ($(UNAME_S),Linux)
    endif
endif