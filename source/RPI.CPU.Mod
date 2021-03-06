(* Runtime support for CPU internals *)
(* Copyright (C) Florian Negele *)

MODULE CPU;

IMPORT SYSTEM;

CONST StackSize* = 4096;
CONST Quantum* = 100000;
CONST CacheLineSize* = 32;
CONST StackDisplacement* = 0;

PROCEDURE Backoff-;
CODE
	MOV	R2, #0x100
loop:
	SUBS	R2, R2, #1
	BNE	loop
END Backoff;

(* cpu control *)
PROCEDURE Delay- (cycles: SIZE);
CODE
	LDR	R2, [FP, #cycles]
delay:
	SUBS	R2, R2, #1
	BNE	delay
END Delay;

PROCEDURE {NORETURN} Reset-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	WriteWord (WDOG, PASSWORD + 1);
	WriteWord (RSTC, PASSWORD + FULLRESET);
	Halt;
END Reset;

PROCEDURE {NORETURN} Halt-;
CODE
	MRS	R2, CPSR
	ORR	R2, R2, #0b1100000
	MSR	CPSR_c, r2
	WFI
END Halt;

PROCEDURE -SaveResult-;
CODE
	STMDB	SP!, {R0, R1}
END SaveResult;

PROCEDURE -RestoreResultAndReturn-;
CODE
	LDMIA	SP!, {R0, R1}
	ADD	SP, FP, #4
	LDMIA	SP!, {FP, PC}
END RestoreResultAndReturn;

(* memory management *)
VAR pageTable {ALIGNED (4000H)}: RECORD entry: ARRAY 4096 OF SIZE END;

PROCEDURE IdentityMapMemory- (size: SIZE);
CONST Section = 2H; Domain0 = 0H; FullAccess = 0C00H; NormalWriteBackAllocate = 100CH; StronglyOrdered = 0H; Shareable = 10000H;
CONST NormalMemory = Section + Domain0 + FullAccess + NormalWriteBackAllocate + Shareable;
CONST StronglyOrderedMemory = Section + Domain0 + FullAccess + StronglyOrdered;
VAR index: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	index := 0; size := size DIV 100000H;
	WHILE index # size DO pageTable.entry[index] := index * 100000H + NormalMemory; INC (index) END;
	WHILE index # LEN (pageTable.entry) DO pageTable.entry[index] := index * 100000H + StronglyOrderedMemory; INC (index) END;
END IdentityMapMemory;

PROCEDURE EnableMemoryManagementUnit-;
CODE
load:
	LDR	R0, [PC, #page-$-8]
	MCR	P15, 0, R0, C2, C0, 0
	B	grant
page:
	d32 pageTable
grant:
	MOV	R0, #0b11
	MCR	P15, 0, R0, C3, C0, 0
enable:
	MRC	P15, 0, R0, C1, C0, 0
	ORR	R0, R0, #0b1	; memory protection
	ORR	R0, R0, #0b100	; data and unified cache
	ORR	R0, R0, #0b100000000000	; branch prediction
	ORR	R0, R0, #0b1000000000000	; instruction cache
	MCR	P15, 0, R0, C1, C0, 0
END EnableMemoryManagementUnit;

PROCEDURE Invalidate- (address: ADDRESS);
CODE
	LDR	R0, [FP, #address]
	BIC	R0, R0, #(CacheLineSize - 1)
	MCR	P15, 0, R0, C7, C6, 1
END Invalidate;

PROCEDURE Clean- (address: ADDRESS);
CODE
	LDR	R0, [FP, #address]
	BIC	R0, R0, #(CacheLineSize - 1)
	MCR	P15, 0, R0, C7, C10, 1
END Clean;

(* hardware registers *)
CONST WDOG* = 03F100024H; RSTC* = 03F10001CH; PASSWORD = 05A000000H; FULLRESET = 000000020H;

CONST GPFSEL0* = 03F200000H; FSEL0* = 0; FSEL1* = 3; FSEL2* = 6; FSEL3* = 9; FSEL4* = 12; FSEL5* = 15; FSEL6* = 18; FSEL7* = 21; FSEL8* = 24; FSEL9* = 27;
CONST GPFSEL1* = 03F200004H; FSEL10* = 0; FSEL11* = 3; FSEL12* = 6; FSEL13* = 9; FSEL14* = 12; FSEL15* = 15; FSEL16* = 18; FSEL17* = 21; FSEL18* = 24; FSEL19* = 27;
			GPFSEL2* = 03F200008H; GPFSEL3* = 03F20000CH; GPFSEL4* = 03F200010H; GPFSEL5* = 03F200014H;
CONST GPSET0* = 03F20001CH; GPSET1* = 03F200020H;
CONST GPCLR0* = 03F200028H; GPCLR1* = 03F20002CH;
CONST GPPUD* = 03F200094H; PUD* = 0;
CONST GPPUDCLK0* = 03F200098H; GPPUDCLK1* = 03F20009CH;

CONST IRQBasicPending* = 03F00B200H; IRQPending1* = 03F00B204H; IRQPending2* = 03F00B208H;
CONST IRQEnable1* = 03F00B210H; IRQEnable2* = 03F00B214H; IRQEnableBasic* = 03F00B218H;
CONST IRQDisable1* = 03F00B21CH; IRQDisable2* = 03F00B220H; IRQDisableBasic* = 03F00B224H;

CONST STCS* = 03F003000H; M0* = 0; M1* = 1; M2* = 2; M3* = 3;
CONST STCLO* = 03F003004H; STCHI* = 03F003008H;
CONST STC0* = 03F00300CH; STC1* = 03F003010H; STC2* = 03F003014H; STC3* = 03F003018H;

CONST FUARTCLK* = 3000000;
CONST UART_DR* = 03F201000H;
CONST UART_FR* = 03F201018H; RXFE* = 4; TXFF* = 5; TXFE* = 7;
CONST UART_IBRD* = 03F201024H;
CONST UART_FBRD* = 03F201028H;
CONST UART_LCRH* = 03F20102CH; FEN* = 4; WLEN8* = {5, 6};
CONST UART_CR* = 03F201030H; UARTEN* = 0; TXE* = 8; RXE* = 9;
CONST UART_IMSC* = 03F201038H; RXIM* = 4;
CONST UART_ICR* = 03F201044H; RXIC* = 4;

PROCEDURE ReadWord- (register: ADDRESS): INTEGER;
CODE
	LDR	R2, [FP, #register]
	LDR	R0, [R2, #0]
END ReadWord;

PROCEDURE ReadMask- (register: ADDRESS): SET;
CODE
	LDR	R2, [FP, #register]
	LDR	R0, [R2, #0]
END ReadMask;

PROCEDURE WriteWord- (register: ADDRESS; value: ADDRESS);
CODE
	LDR	R2, [FP, #register]
	LDR	R3, [FP, #value]
	STR	R3, [R2, #0]
END WriteWord;

PROCEDURE WriteMask- (register: ADDRESS; value: SET);
CODE
	LDR	R2, [FP, #register]
	LDR	R3, [FP, #value]
	STR	R3, [R2, #0]
END WriteMask;

PROCEDURE Mask- (register: ADDRESS; value: SET);
CODE
	LDR	R2, [FP, #register]
	LDR	R3, [FP, #value]
	LDR	R4, [R2, #0]
	ORR	R4, R4, R3
	STR	R4, [R2, #0]
END Mask;

PROCEDURE Unmask- (register: ADDRESS; value: SET);
CODE
	LDR	R2, [FP, #register]
	LDR	R3, [FP, #value]
	LDR	R4, [R2, #0]
	BIC	R4, R4, R3
	STR	R4, [R2, #0]
END Unmask;

(* combined mask / unmask: clear mask and set value *)
PROCEDURE MaskIn-(register: ADDRESS; mask, value: SET);
CODE
	LDR	R2, [FP, #register]
	LDR	R3, [FP, #mask]
	LDR	R4, [FP, #value]
	LDR	R5, [R2, #0]
	BIC	R5, R5, R3
	ORR R5, R5, R4
	STR	R5, [R2, #0]
END MaskIn;

(* interrupt handling *)
CONST Interrupts* = 7;
CONST UndefinedInstruction* = 1; SoftwareInterrupt* = 2; PrefetchAbort* = 3; DataAbort* = 4; IRQ* = 5; FIQ* = 6; IRQ0* = IRQ;

TYPE InterruptHandler* = PROCEDURE (index: SIZE);

VAR handlers: ARRAY Interrupts OF InterruptHandler;

PROCEDURE InstallInterrupt- (handler: InterruptHandler; index: SIZE): InterruptHandler;
VAR previous: InterruptHandler;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (handler # NIL); ASSERT (index < Interrupts);
	REPEAT previous := CAS (handlers[index], NIL, NIL) UNTIL CAS (handlers[index], previous, handler) = previous;
	RETURN previous;
END InstallInterrupt;

PROCEDURE HandleInterrupt (index: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	SYSTEM.SetActivity (NIL);
	IF index = IRQ THEN WriteMask (IRQDisable1, ReadMask (IRQPending1)); WriteMask (IRQDisable2, ReadMask (IRQPending2)) END;
	IF handlers[index] # NIL THEN handlers[index] (index) ELSE HALT (1234) END;
END HandleInterrupt;

PROCEDURE DisableInterrupt- (index: SIZE);
VAR previous: InterruptHandler;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (index < Interrupts);
	IF index = IRQ THEN WriteMask (IRQDisable1, ReadMask (IRQEnable1)); WriteMask (IRQDisable2, ReadMask (IRQEnable2)) END;
	REPEAT previous := CAS (handlers[index], NIL, NIL) UNTIL CAS (handlers[index], previous, NIL) = previous;
END DisableInterrupt;

PROCEDURE EnableIRQ- (index: SIZE);
BEGIN
	(* no effect -- only for compatibility *)
END EnableIRQ;

PROCEDURE DisableIRQ-(index: SIZE);
BEGIN
	(* no effect -- only for compatibility *)
END DisableIRQ;


PROCEDURE Initialize-;
CODE
	ADD	R2, PC, #vector-$-8
	MOV	R3, #0
	ADD	R4, R3, #vector_end - vector
copy:
	CMP	R3, R4
	BEQ	vector_end
	LDR	r5, [R2], #4
	STR	r5, [R3], #4
	B	copy
vector:
	LDR	PC, [PC, #header-$-8]
	LDR	PC, [PC, #undefined_instruction-$-8]
	LDR	PC, [PC, #software_interrupt-$-8]
	LDR	PC, [PC, #prefetch_abort-$-8]
	LDR	PC, [PC, #data_abort-$-8]
	MOV	R0, R0
	LDR	PC, [PC, #irq-$-8]
fiq:
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, LR}
	MOV	R2, #UndefinedInstruction
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, LR}
	SUBS	PC, LR, #4
header:
	d32	0x8000
undefined_instruction:
	d32	UndefinedInstructionHandler
software_interrupt:
	d32	SoftwareInterruptHandler
prefetch_abort:
	d32	PrefetchAbortHandler
data_abort:
	d32	DataAbortHandler
irq:
	d32	IRQHandler
handle:
	d32	HandleInterrupt
vector_end:
	MOV	R2, #0b10001
	MSR	CPSR_c, R2
	MOV	SP, #0x7000
	MOV	R2, #0b10010
	MSR	CPSR_c, R2
	MOV	SP, #0x6000
	MOV	R2, #0b10111
	MSR	CPSR_c, R2
	MOV	SP, #0x5000
	MOV	R2, #0b11011
	MSR	CPSR_c, R2
	MOV	SP, #0x4000
	MOV	R2, #0b10011
	MSR	CPSR_c, R2
END Initialize;

PROCEDURE {PLAIN} UndefinedInstructionHandler;
CODE
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOV	R2, #UndefinedInstruction
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOVS	PC, LR
handle:
	d32	HandleInterrupt
END UndefinedInstructionHandler;

PROCEDURE {PLAIN} SoftwareInterruptHandler;
CODE
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOV	R2, #SoftwareInterrupt
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOVS	PC, LR
handle:
	d32	HandleInterrupt
END SoftwareInterruptHandler;

PROCEDURE {PLAIN} PrefetchAbortHandler;
CODE
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOV	R2, #PrefetchAbort
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	SUBS	PC, LR, #4
handle:
	d32	HandleInterrupt
END PrefetchAbortHandler;

PROCEDURE {PLAIN} DataAbortHandler;
CODE
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOV	R2, #DataAbort
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	SUBS	PC, LR, #4
handle:
	d32	HandleInterrupt
END DataAbortHandler;

PROCEDURE {PLAIN} IRQHandler;
CODE
	STMDB	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	MOV	R2, #IRQ
	STR	R2, [SP, #-4]!
	LDR	R2, [PC, #handle-$-8]
	BLX	R2
	ADD	SP, SP, #4
	LDMIA	SP!, {R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11, R12, LR}
	SUBS	PC, LR, #4
handle:
	d32	HandleInterrupt
END IRQHandler;

END CPU.
