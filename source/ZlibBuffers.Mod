(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE ZlibBuffers;	(** Stefan Walthert  **)

(*	2002.04.03	g.f.	procedure Drain fixed for SPARC	*)

IMPORT
	SYSTEM;
		(*
			should be portable even if SYSTEM is imported:
			- PUT and GET only with byte sized operands
			- no overlapping MOVEs (unless malignant client passes buffer memory to buffer operations)
		*)

TYPE
	(** input/output buffer **)
	Buffer* = RECORD
		avail-: SIZE;	(** number of bytes that can be produced/consumed **)
		size-: SIZE;	(** total number of bytes in buffer memory **)
		totalOut-, totalIn-: SIZE;	(** total number of bytes produced/consumed **)
		next: ADDRESS;	(* address of next byte to produce/consume **)
		adr: ADDRESS;	(* buffer memory *)
	END;


(** set buf.totalIn and buf.totalOut to zero **)
PROCEDURE Reset*(VAR buf: Buffer);
BEGIN
	buf.totalIn := 0; buf.totalOut := 0
END Reset;

(** initialize buffer on memory in client space **)
PROCEDURE Init* (VAR buf: Buffer; CONST mem: ARRAY OF CHAR; offset, size, avail: SIZE);
BEGIN
	ASSERT((0 <= offset) & (0 < size) & (offset + size <= LEN(mem)), 100);
	ASSERT((0 <= avail) & (avail <= size),101);
	buf.avail := avail; buf.size := size; buf.adr := ADDRESSOF(mem[offset]); buf.next := buf.adr;
END Init;

(** read byte from (input) buffer **)
PROCEDURE Read* (VAR buf: Buffer; VAR ch: CHAR);
BEGIN
	ASSERT(buf.avail > 0, 100);
	SYSTEM.GET(buf.next, ch);
	INC(buf.next); DEC(buf.avail); INC(buf.totalIn)
END Read;

(** read len bytes from (input) buffer **)
PROCEDURE ReadBytes* (VAR buf: Buffer; VAR dst: ARRAY OF CHAR; offset, len: SIZE);
BEGIN
	ASSERT((0 <= offset) & (0 < len) & (offset + len <= LEN(dst)) & (len <= buf.avail), 100);
	SYSTEM.MOVE(buf.next, ADDRESSOF(dst[offset]), len);
	 INC(buf.next, len); DEC(buf.avail, len); INC(buf.totalIn, len)
END ReadBytes;

(** write byte into (output) buffer **)
PROCEDURE Write* (VAR buf: Buffer; ch: CHAR);
BEGIN
	ASSERT(buf.avail > 0, 100);
	SYSTEM.PUT(buf.next, ch);
	INC(buf.next); DEC(buf.avail); INC(buf.totalOut)
END Write;

(** write len bytes into (output) buffer **)
PROCEDURE WriteBytes* (VAR buf: Buffer; CONST src: ARRAY OF CHAR; offset, len: SIZE);
BEGIN
	ASSERT((0 <= offset) & (0 < len) & (offset + len <= LEN(src)) & (len <= buf.avail), 100);
	SYSTEM.MOVE(ADDRESSOF(src[offset]), buf.next, len);
	INC(buf.next, len); DEC(buf.avail, len); INC(buf.totalOut, len)
END WriteBytes;

(** rewind previously empty input buffer to first position after it has been filled with new input **)
PROCEDURE Rewind* (VAR buf: Buffer; avail: SIZE);
BEGIN
	ASSERT(buf.avail = 0, 100);
	ASSERT((0 <= avail) & (avail <= buf.size), 101);
	buf.next := buf.adr; buf.avail := avail
END Rewind;

(** move position of next read for -offset bytes **)
PROCEDURE Reread* (VAR buf: Buffer; offset: SIZE);
BEGIN
	ASSERT((0 <= offset) & (buf.avail + offset <= buf.size), 101);
	DEC(buf.next, offset); INC(buf.avail, offset)
END Reread;

(** restart writing at starting position of output buffer after it has been emptied **)
PROCEDURE Rewrite* (VAR buf: Buffer);
BEGIN
	buf.next := buf.adr; buf.avail := buf.size
END Rewrite;

(** fill input buffer with new bytes to consume **)
PROCEDURE Fill* (VAR buf: Buffer; CONST src: ARRAY OF CHAR; offset, size: SIZE);
BEGIN
	ASSERT((0 <= offset) & (0 < size) & (offset + size <= LEN(src)), 100);
	ASSERT(buf.avail + size <= buf.size, 101);
	IF buf.avail # 0 THEN
		SYSTEM.MOVE(buf.next, buf.adr, buf.avail)
	END;
	buf.next := buf.adr + buf.avail;
	SYSTEM.MOVE(ADDRESSOF(src[offset]), buf.next, size);
	INC(buf.avail, size)
END Fill;

(** extract bytes from output buffer to make room for new bytes **)
PROCEDURE Drain* (VAR buf: Buffer; VAR dst: ARRAY OF CHAR; offset, size: SIZE);
VAR i, n: SIZE; s, d: ADDRESS; c: CHAR;
BEGIN
	ASSERT((0 <= offset) & (0 < size) & (offset + size <= LEN(dst)), 100);
	ASSERT(buf.avail + size <= buf.size, 101);	(* can't consume more than is in buffer *)
	SYSTEM.MOVE(buf.adr, ADDRESSOF(dst[offset]), size);
	(*SYSTEM.MOVE(buf.adr + size, buf.adr, buf.size - buf.avail - size);   overlapping moves don't work on SPARC !*)
	n := buf.size - buf.avail - size;  s := buf.adr + size;  d := buf.adr;
	FOR i := 0 TO n - 1 DO SYSTEM.GET( s + i, c );  SYSTEM.PUT( d + i, c ) END;
	INC(buf.avail, size); DEC(buf.next, size);
END Drain;

END ZlibBuffers.
