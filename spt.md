## Notes on the techniques used in this ROM

_David Giller, KI3V_

Writing any non-trivial program on a Z80 to operate without using RAM is an extremely tight constraint.  A few of the restrictions implied by lack of RAM are:
- You cannot use the `CALL` or `RET` instructions in any conventional sense
- You cannot store variables to the stack using `PUSH`, or move data between registers with `PUSH` and `POP`
- You can only keep track of as much variable information as will fit in the registers
	- ... and some of those registers, especially `A`, will be consumed by just about any operation or computation at all
- Moving data between registers is hampered by the fact that some pathways generally use RAM as an intermediate location

I by no means an expert at Z80 assembly language; this project is my first Z80 program.  I did not invent the techniques used in this program, although I have not seen them combined in exactly this form elsewhere.  This was a learning experience for me, and this document aims to help others who are starting from a similar level of experience to mine learn some of the lessons I did.

## Subroutines without a RAM stack

The initial inspiration for the techniques used in this project was taken [from this article by Jens Madsen on the z80.info web site](http://www.z80.info/jmnomem.htm).  Jens describes how a 'stack' of sorts can be assembled by hand into ROM, and the addresses and parameters that form operations made out of machine-language primitives (subroutines that don't call any other subroutines) can be listed in a very space-efficient form and thus composed into larger, more complex programs without using the `CALL` instruction, RAM, or the stack for return addresses.

(For brevity I'll call this _Jens' method_, though I don't believe he claims to have invented it.  If anyone knows who did, I would be very interested to hear the story.)

## Threaded code

These days, the word _threading_ almost always means concurrent multiprocessing.  But traditionally, the term "threaded code" had a different meaning, one more familiar to Forth language programmers.  

Threaded code in this sense is a technique of stringing subroutines together using sequences of codes representing operations; these operations have been likened to user-definable opcodes in an abstract virtual machine.  The extremely simple interpreter that ran this virtual machine is called an _address interpreter_.

In _Direct Threaded Code_, the opcodes are just the address of the machine-language subroutines that implement each operation.  This is like a string of `CALL mysubroutine` operations, without the `CALL` opcode on the front.  Interspersed with the opcodes, as necessary, are any parameters required by the machine-language opcode subroutines.

The technique described above by Jens is basically a form of direct threading code.  However, this method still only allowed for one level of subroutines, and the order needs to be determined at compile time.  More importantly, subroutines can start the CPU on a new 'stack' or stream of instructions, but can't perform a `CALL` to other code that returns where the current code left off.

Threaded code is not generally a technique to avoid using RAM or a stack; quite the contrary, the Forth language makes extensive use of at least _two_ stacks for fundamental operation.  I needed to find a way to extend this mechanism to allow subroutine calls, even if only in a very limited form, without using RAM for variables of for a CPU stack.

## SPT: Stack Pointer Threading

I implemented a very simple address interpreter based on Jens' method.

To start defining a thread of code, I created the `spthread_begin` macro.  All this does is define a ROM-based 'stack' with its "top" beginning immediately after the macro is invoked.  _Z80 stacks grow from high addresses to low ones, so the "top" of the stack is the lowest address._

At the end of a string of threaded code, the `spthread_end` macro wraps it up.

Defining threaded code, then, just looks like this:

```
	spthread_begin
	dw proc1
	dw proc1arg1
	dw proc2
	dw proc2arg1
	dw proc2arg2
	dw proc3
	spthread_end
```

This can be written more succinctly, which conveniently also looks more like a high level language:

```
	spthread_begin
	dw proc1, proc1arg1
	dw proc2, proc2arg1, proc2arg2
	dw proc3
	spthread_end
```

These macros expand to generate code that looks like this:

```
	ld sp,.threadstart
	ret
.threadstart:
	dw proc1, proc1arg1
	dw proc2, proc2arg1, proc2arg2
	dw proc3
	dw .threadend
.threadend:

```
Conbine the above with subroutines such as the following:

```
proc1:	pop hl
	; do some processing
	; ...
	ret

proc2:	pop hl
	pop bc
	; do some useful work
	; ...
	ret

proc3:	; do something without arguments
	; ...
	; ...
	ret

```

For lack of a more creative term, I call this "Stack Pointer Threading", or SPT.  This is not an invention of mine, just an implementation of the method Jens described.  The trick is to remember that the `SP` register serves the purpose of the instruction pointer, for the threaded code addresses.

(For attempted clarity, I will use the term "instruction pointer" to refer to threaded code, to distinguis between that and the Z80's `PC` register.)

The "interpreter" consists of two instructions: `RET` calls the next threaded operation, and `POP` fetches a parameter from the instruction stream.  It's just two Z80 instructions.  There is no interpreter subroutine.

Now we have code that 'calls' subroutines &mdash; limited to one level deep, and with only fixed arguments passed on the stack.  Still, they feel almost like regular subroutines, save for the fact that `POP` instructions are not balanced with `PUSH` instructions anywhere else.

The final piece, however, is how to make more than one level of subroutine call.  I came to the solution for this after pondering on the advice by [Jim Westfall](https://github.com/jwestfall69) to remember the `EX` and `EXX` instructions.  These instructions are not really designed for general use; they are really intended to reduce context switching time in interrupt service routines by shortening the time required to save a single set of registers (instead of saving them to the stack).  This ROM does not use interrupts, but the magic idea there is _"instead of saving them to the stack"_.

## Simulating the stack using the Z80 alternate register set

The alternate resister set that is swapped in and out by the `EX AF,AF'` and `EXX` instructions don't include the stack pointer `SP`.  They do, however, include `HL`, which happens to be the only register to and from which the `SP` register can be transferred without using RAM.

The SPT address interpreter can make one level of subroutine calls, but those calls cannot make deeper calls because we need a place to save the `SP` register (just like the Z80 must store a copy of the `PC` register on the stack before jumping to a subroutine using the `CALL` instruction).

Using this knowlege, I created a set of macros to form the function prologue and epilogue for subroutines that want to make deeper threaded subroutine calls.  The sequence for a threaded subroutine call expands to look like this:

```
 .prologue
 	exx			; prologue: push SP, (threaded IP),
				; onto the emulated stack
 	ex	de,hl		; copy hl' to de'
 	ld	hl,0		; copy sp to hl'
 	add	hl,sp
 	exx
 	ld sp,.threadstart
	ret			; begin address interpreter
.threadstart
	db	func1, func1arg1
	db	func2,
	; ...
	db	.threadend
.threadend
 	exx			; epilogue: pop the previous SP off the emulated stack
 	ld	sp,hl		; resume from the thread location saved in hl'
 	ex	de,hl		; copy de' to hl'
 	exx
	ret
```

This gives a two-level threaded-code stack, which gives up to three levels of subroutine nesting:

- top level program, with a `spthread_begin` and `spthread_end` threaded code section (threaded IP saved in `DE'`)
	- First subroutine call, using prologue above (IP saved in `HL'`)
		- Second subroutine call, using prologue above (IP saved in `SP`)
			- Third subroutine call &mdash; can't make further subroutine calls

If necessary, it would be possible to extend this method by one more register by also using `BC'`.  However, this seems excessive.  Operating without RAM is for special situations such as this RAM testing firmware, and it seems likely that such programs can be structured to live with three levels of nesting or less.

It's worth saying this here: this is extremely slow compared to native Z80 `CALL` and `RET`.  This technique is for when you don't have RAM and can't use `CALL`!

There are a handful of refinements such as the ability to jump to a copy of the epliogue (not the prologue), and even returning to the previous threaded 'stack' frame from within a primitive operation, but the useful portions of the method are described here.

I doubt that I am the first to use this method, and I doubt that I have implemented it in the optimal way.  I would be very interested to hear suggestions for improving this technique.  Please submit an "Issue" with your suggestion so that we can get in contact.

## _Virtual Machine_ revisited

If it seems like a stretch to call the threaded code a "virtual machine", consider that the technique described above already permits code like the following, which I think you'll agree starts to look like assembly language for a fictitious virtual processor:

```
main_program:
	spthread_begin
.loop:	dw sendbyte, $FFFF
	dw readbyte $FF
	dw jump_nonzero, .loop
	spthread_end
	; ... other code here
	halt

sendbyte:
	pop	bc
	out	(c),b
	ret

readbyte:
	pop	bc
	in	b,(c)
	ret

jump_nonzero:
	pop	hl
	sub	a
	cp	b
	ret	z
	ld	sp,hl		; SP now points to .loop and...
	ret			; this will continue execution at sendbyte
```

By changing `SP` from a machine-level threaded-code "instruction", your code can move around inside the threaded instruction stream.

## But... why?

Some might be wondering why not simply use the `IX` and `IY` registers to store return addresses.  After all, it is very easy to make a macro to do this:

```
	ld	iy,$+3		; save the return address
	jp	musub		; 
	; ...

mysub:	; do something useful
	; ...
	jp	(iy)		; return from whence we came
```

We have three registers available with similar powers, `IX`, `IY`, and even `HL`.  And this is _much_ faster and simpler than the whole SPT mess.

The reason is simple.  In this diagnostics ROM, where the goal was to operate with no RAM whatsoever, giving up `IX` and `IY` was too high a price to pay when they are needed for global variables.
