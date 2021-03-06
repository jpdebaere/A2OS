(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE BIT;	(** portable *)	(* tk 12.2.96 *)
(** AUTHOR "tk"; PURPOSE "Bit manipulation"; *)

	IMPORT S := SYSTEM;

	TYPE
		SHORTCARD* = SIGNED8;
		CARDINAL* = SIGNED16;
		LONGCARD* = SIGNED32;

	CONST
		rbo = FALSE;	(* reverse bit ordering, e.g. PowerPC*)
		risc = FALSE;	(* risc architecture - no support for 8 and 16-bit rotations *)

	(** bitwise exclusive or: x XOR y *)
	PROCEDURE CXOR*(x, y: CHAR): CHAR;
	BEGIN RETURN CHR(S.VAL(SIGNED32, S.VAL(SET32, LONG(ORD(x))) / S.VAL(SET32, LONG(ORD(y)))))
	END CXOR;

	PROCEDURE SXOR*(x, y: SIGNED8): SIGNED8;
	BEGIN RETURN SHORT(SHORT(S.VAL(SIGNED32, S.VAL(SET32, LONG(LONG(x))) / S.VAL(SET32, LONG(LONG(y))))))
	END SXOR;

	PROCEDURE IXOR*(x, y: SIGNED16): SIGNED16;
	BEGIN RETURN SHORT(S.VAL(SIGNED32, S.VAL(SET32, LONG(x)) / S.VAL(SET32, LONG(y))))
	END IXOR;

	PROCEDURE LXOR*(x, y: SIGNED32): SIGNED32;
	BEGIN RETURN S.VAL(SIGNED32, S.VAL(SET32, x) / S.VAL(SET32, y))
	END LXOR;


	(** bitwise or: x OR y *)
	PROCEDURE COR*(x, y: CHAR): CHAR;
	BEGIN RETURN CHR(SIGNED32(SET(ORD(x)) + SET(ORD(y))))
	END COR;

	PROCEDURE SOR*(x, y: SIGNED8): SIGNED8;
	BEGIN RETURN SHORT(SHORT(S.VAL(SIGNED32, S.VAL(SET32, LONG(LONG(x))) + S.VAL(SET32, LONG(LONG(y))))))
	END SOR;

	PROCEDURE IOR*(x, y: SIGNED16): SIGNED16;
	BEGIN RETURN SIGNED16(SET(x) + SET(y))
	END IOR;

	PROCEDURE LOR*(x, y: SIGNED32): SIGNED32;
	BEGIN RETURN S.VAL(SIGNED32, S.VAL(SET32, x) + S.VAL(SET32, y))
	END LOR;


	(** bitwise and: x AND y *)
	PROCEDURE CAND*(x, y: CHAR): CHAR;
	BEGIN RETURN CHR(S.VAL(SIGNED32, S.VAL(SET32, LONG(ORD(x))) * S.VAL(SET32, LONG(ORD(y)))))
	END CAND;

	PROCEDURE SAND*(x, y: SIGNED8): SIGNED8;
	BEGIN RETURN SHORT(SHORT(S.VAL(SIGNED32, S.VAL(SET32, LONG(LONG(x))) * S.VAL(SET32, LONG(LONG(y))))))
	END SAND;

	PROCEDURE IAND*(x, y: SIGNED16): SIGNED16;
	BEGIN RETURN SHORT(S.VAL(SIGNED32, S.VAL(SET32, LONG(x)) * S.VAL(SET32, LONG(y))))
	END IAND;

	PROCEDURE LAND*(x, y: SIGNED32): SIGNED32;
	BEGIN RETURN S.VAL(SIGNED32, S.VAL(SET32, x) * S.VAL(SET32, y))
	END LAND;


	(** bitwise logical left-shift: x shifted n *)
	PROCEDURE CLSH*(x: CHAR; n: SIGNED8): CHAR;
	BEGIN
		IF risc THEN RETURN CHR(LSH(SIGNED32(SET(ORD(x)) * SET(0FFH)), n))
		ELSE RETURN LSH(x, n) END
	END CLSH;

	PROCEDURE SLSH*(x: SIGNED8; n: SIGNED8): SIGNED8;
	BEGIN
		IF risc THEN RETURN SHORT(SHORT(LSH(S.VAL(SIGNED32, S.VAL(SET32, LONG(LONG(x))) * SET32(0FFH)), n)))
		ELSE RETURN LSH(x, n) END
	END SLSH;

	PROCEDURE ILSH*(x: SIGNED16; n: SIGNED8): SIGNED16;
	BEGIN
		IF risc THEN RETURN SHORT(LSH(SIGNED32(SET(LONG(x)) * SET(0FFFFH)), n))
		ELSE RETURN LSH(x, n) END
	END ILSH;

	PROCEDURE LLSH*(x: SIGNED32; n: SIGNED8): SIGNED32;
	BEGIN RETURN LSH(x, n)
	END LLSH;


	(** bitwise rotation: x rotatated by n bits *)
	PROCEDURE CROT*(x: CHAR; n: SIGNED8): CHAR;
		VAR s0, s1: SET; i: SIGNED16;
	BEGIN
		IF risc THEN
			s0 := SET(ORD(x)); s1 := {};
			IF rbo THEN
				i := 0; WHILE i < 8 DO
					IF 31-i IN s0 THEN INCL(s1, 31 - ((i+n) MOD 8)) END;
					INC(i)
				END;
			ELSE
				i := 0; WHILE i < 8 DO
					IF i IN s0 THEN INCL(s1, (i+n) MOD 8) END;
					INC(i)
				END;
			END;
			RETURN CHR(SIGNED32(s1))
		ELSE RETURN ROT(x, n) END;
	END CROT;

	PROCEDURE SROT*(x: SIGNED8; n: SIGNED8): SIGNED8;
		VAR s0, s1: SET; i: SIGNED16;
	BEGIN
		IF risc THEN
			s0 := S.VAL(SET32, LONG(LONG(x))); s1 := {};
			IF rbo THEN
				i := 0; WHILE i < 8 DO
					IF 31-i IN s0 THEN INCL(s1, 31 - ((i+n) MOD 8)) END;
					INC(i)
				END;
			ELSE
				i := 0; WHILE i < 8 DO
					IF i IN s0 THEN INCL(s1, (i+n) MOD 8) END;
					INC(i)
				END;
			END;
			RETURN SIGNED8(s1)
		ELSE RETURN ROT(x, n) END;
	END SROT;

	PROCEDURE IROT*(x: SIGNED16; n: SIGNED8): SIGNED16;
		VAR s0, s1: SET; i: SIGNED16;
	BEGIN
		IF risc THEN
			s0 := SET(x); s1 := {};
			IF rbo THEN
				i := 0; WHILE i < 16 DO
					IF 31-i IN s0 THEN INCL(s1, 31 - ((i+n) MOD 16)) END;
					INC(i)
				END;
			ELSE
				i := 0; WHILE i < 16 DO
					IF i IN s0 THEN INCL(s1, (i+n) MOD 16) END;
					INC(i)
				END;
			END;
			RETURN SIGNED16(s1)
		ELSE RETURN ROT(x, n) END;
	END IROT;

	PROCEDURE LROT*(x: SIGNED32; n: SIGNED8): SIGNED32;
	BEGIN RETURN ROT(x, n)
	END LROT;


	(** swap bytes to change byteordering *)
	PROCEDURE ISWAP*(x: SIGNED16): SIGNED16;
		TYPE integer = ARRAY 2 OF CHAR; VAR a, b: integer;
	BEGIN a := S.VAL(integer, x); b[0] := a[1]; b[1] := a[0]; RETURN S.VAL(SIGNED16, b)
	END ISWAP;

	PROCEDURE LSWAP*(x: SIGNED32): SIGNED32;
		TYPE longint = ARRAY 4 OF CHAR; VAR a, b: longint;
	BEGIN a := S.VAL(longint, x); b[0] := a[3]; b[1] := a[2]; b[2] := a[1]; b[3] := a[0]; RETURN S.VAL(SIGNED32, b)
	END LSWAP;


	(** test bit n in x*)
	PROCEDURE CBIT*(x: CHAR; n: SIGNED8): BOOLEAN;
	BEGIN ASSERT((n >= 0) & (n <= 7));
		IF rbo THEN RETURN (31-n) IN SET(ORD(x)) ELSE RETURN n IN SET(ORD(x)) END
	END CBIT;

	PROCEDURE BIT*(x: SIGNED32; n: SIGNED8): BOOLEAN;
	BEGIN ASSERT((n >= 0) & (n <= 31));
		IF rbo THEN RETURN (31-n) IN S.VAL(SET32, x) ELSE RETURN n IN S.VAL(SET32, x) END
	END BIT;


	(** set bit n in x*)
	PROCEDURE CSETBIT*(VAR x: CHAR; n: SIGNED8);
		VAR i: SIGNED32;
	BEGIN ASSERT((n >= 0) & (n <= 7));
		i := ORD(x); IF rbo THEN INCL(S.VAL(SET32, i), 31-n) ELSE INCL(S.VAL(SET32, i), n) END; x := CHR(i)
	END CSETBIT;

	PROCEDURE SSETBIT*(VAR x: SIGNED8; n: SIGNED8);
		VAR i: SIGNED32;
	BEGIN ASSERT((n >= 0) & (n <= 7));
		i := LONG(LONG(x)); IF rbo THEN INCL(S.VAL(SET32, i), 31-n) ELSE INCL(S.VAL(SET32, i), n) END; x := SHORT(SHORT(i))
	END SSETBIT;

	PROCEDURE ISETBIT*(VAR x: SIGNED16; n: SIGNED8);
		VAR i: SIGNED32;
	BEGIN ASSERT((n >= 0) & (n <= 15));
		i := LONG(x); IF rbo THEN INCL(S.VAL(SET32, i), 31-n) ELSE INCL(S.VAL(SET32, i), n) END; x := SHORT(i)
	END ISETBIT;

	PROCEDURE LSETBIT*(VAR x: SIGNED32; n: SIGNED8);
	BEGIN ASSERT((n >= 0) & (n <= 31));
		IF rbo THEN INCL(S.VAL(SET32, x), 31-n) ELSE INCL(S.VAL(SET32, x), n) END
	END LSETBIT;


	(** clear bit n in x*)
	PROCEDURE CCLRBIT*(VAR x: CHAR; n: SIGNED8);
		VAR i: SIGNED32;
	BEGIN ASSERT(ABS(n) < 8);
		i := ORD(x); IF rbo THEN EXCL(S.VAL(SET32, i), 31-n) ELSE EXCL(S.VAL(SET32, i), n) END; x := CHR(i)
	END CCLRBIT;

	PROCEDURE SCLRBIT*(VAR x: SIGNED8; n: SIGNED8);
		VAR i: SIGNED32;
	BEGIN ASSERT(ABS(n) < 8);
		i := LONG(LONG(x)); IF rbo THEN EXCL(S.VAL(SET32, i), 31-n) ELSE EXCL(S.VAL(SET32, i), n) END; x := SHORT(SHORT(i))
	END SCLRBIT;

	PROCEDURE ICLRBIT*(VAR x: SIGNED16; n: SIGNED8);
		VAR i: SIGNED32;
	BEGIN ASSERT(ABS(n) < 16);
		i := LONG(x); IF rbo THEN EXCL(S.VAL(SET32, i), 31-n) ELSE EXCL(S.VAL(SET32, i), n) END; x := SHORT(i)
	END ICLRBIT;

	PROCEDURE LCLRBIT*(VAR x: SIGNED32; n: SIGNED8);
	BEGIN IF rbo THEN EXCL(S.VAL(SET32, x), 31-n) ELSE EXCL(S.VAL(SET32, x), n) END
	END LCLRBIT;


	(** unsigned comparison: x < y *)
	PROCEDURE SLESS*(x, y: SHORTCARD): BOOLEAN;
	BEGIN
		RETURN
			S.VAL(SIGNED32, S.VAL(SET32, LONG(LONG(x))) * SET32(0FFH))
		 	<
		 S.VAL(SIGNED32, S.VAL(SET32, LONG(LONG(y))) * SET32(0FFH));
	END SLESS;

	PROCEDURE ILESS*(x, y: CARDINAL): BOOLEAN;
	BEGIN
		RETURN
			SIGNED32(SET(LONG(x)) * SET(0FFFFH))
		<
			SIGNED32(SET(LONG(y)) * SET(0FFFFH))
	END ILESS;

	PROCEDURE LLESS*(x, y: LONGCARD): BOOLEAN;
		VAR x0, y0: SIGNED32;
	BEGIN x0 := LSH(x, -1); y0 := LSH(y, -1);
		IF x0 = y0 THEN RETURN x MOD 2 < y MOD 2 ELSE RETURN x0 < y0 END
	END LLESS;


	(** unsigned comparison: x <= y *)
	PROCEDURE SLESSEQ*(x, y: SHORTCARD): BOOLEAN;
	BEGIN
		RETURN
			S.VAL(SIGNED32, S.VAL(SET32, LONG(LONG(x))) * SET32( 0FFH))
		<=
			S.VAL(SIGNED32, S.VAL(SET32, LONG(LONG(y))) * SET32( 0FFH))
	END SLESSEQ;

	PROCEDURE ILESSEQ*(x, y: CARDINAL): BOOLEAN;
	BEGIN
		RETURN
			SIGNED32(SET(LONG(x)) * SET(0FFFFH))
		<=
			SIGNED32(SET(LONG(y)) * SET(0FFFFH))
	END ILESSEQ;

	PROCEDURE LLESSEQ*(x, y: LONGCARD): BOOLEAN;
		VAR x0, y0: SIGNED32;
	BEGIN x0 := LSH(x, -1); y0 := LSH(y, -1);
		IF x0 = y0 THEN RETURN x MOD 2 <= y MOD 2 ELSE RETURN x0 <= y0 END
	END LLESSEQ;


	(** unsigned division: x DIV y *)
	PROCEDURE SDIV*(x, y: SHORTCARD): SHORTCARD;
	BEGIN RETURN SHORT(SHORT(S.VAL(SIGNED32, S.VAL(SET32, LONG(LONG(x))) * SET32(0FFH)) DIV y))
	END SDIV;

	PROCEDURE IDIV*(x, y: CARDINAL): CARDINAL;
	BEGIN RETURN SHORT(S.VAL(SIGNED32, S.VAL(SET32, LONG(x)) * SET32(0FFFFH))) DIV y;
	END IDIV;

	PROCEDURE LDIV*(x, y: LONGCARD): LONGCARD;
		CONST m = 4.294967296D9;
		VAR x0, y0: FLOAT64;
	BEGIN IF x < 0 THEN x0 := m - x ELSE x0 := x END;
		IF y < 0 THEN y0 := m - y ELSE y0 := y END;
		RETURN ENTIER(x0 / y0)
	END LDIV;

END BIT.

