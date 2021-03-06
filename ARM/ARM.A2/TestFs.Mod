MODULE TestFs;

IMPORT
	SYSTEM, Random, Files, Kernel, Commands, FoxBasic, Strings;

TYPE

	Writer  = OBJECT
	VAR
		id: SIGNED32;
		file: Files.File;
		fw: Files.Writer;
		fileSize: SIGNED64;
		byteCount: SIGNED64;
		rndData, rndUpdate: Random.Generator;

		tStart: Kernel.MilliTimer;
		startByteCount: SIGNED64;

		fileName0: Files.FileName;
		partNum: SIGNED32;
		partByteCount: SIGNED32;

		run := FALSE, exited := FALSE: BOOLEAN;

		PROCEDURE &InitWriter(id: SIGNED32; CONST fileName: ARRAY OF CHAR; fileSize: SIGNED64);
		BEGIN
			ASSERT(~exited);

			file := Files.New(fileName);
			ASSERT(file # NIL);
			Files.Register(file);

			Files.OpenWriter(fw,file,0);

			NEW(rndData);
			rndData.InitSeed(id);

			NEW(rndUpdate);
			rndUpdate.InitSeed(-id);

			SELF.id := id;
			SELF.fileSize := fileSize;

			COPY(fileName,fileName0);
			partNum := 0;

			byteCount := 0;
			partByteCount := 0;

			run := TRUE;
		END InitWriter;

		PROCEDURE Exit;
		BEGIN{EXCLUSIVE}
			run := FALSE;
			AWAIT(exited);
		END Exit;

		PROCEDURE Start;
		BEGIN {EXCLUSIVE}
			run := TRUE
		END Start;

		PROCEDURE Pause;
		BEGIN {EXCLUSIVE}
			run := FALSE
		END Pause;

		PROCEDURE Running (): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN run
		END Running;

		PROCEDURE Exited (): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN exited
		END Exited;

		PROCEDURE Loop;
		VAR
			v: SIGNED32;
			strNum: ARRAY 16 OF CHAR;
			str: Files.FileName;
			t: SIGNED32;
		BEGIN
			WHILE run & ((fileSize <= 0) OR (byteCount < fileSize)) & (fw.res = 0) DO
				v := rndData.Integer();
				fw.RawLInt(v);
				INC(byteCount,SIZEOF(SIGNED32));
				INC(partByteCount,SIZEOF(SIGNED32));

				IF partByteCount MOD 0x1000000 = 0 THEN
					Kernel.SetTimer(tStart,0);
					startByteCount := byteCount;
				END;
(*
				IF rndUpdate.Dice(4096) = 0 THEN (* Files.DefaultWriterSize *)
					fw.Update;
				END;
*)
				IF partByteCount = 0x40000000 THEN (* 1GB parts *)
					partByteCount := 0;
					INC(partNum);
					fw.Update;

					TRACE("closing file...");
					t := Kernel.GetTicks();
					file.Close;
					t := Kernel.GetTicks() - t;
					TRACE("closed file",t);

					Strings.IntToStr(partNum,strNum);
					Strings.Concat(fileName0,".p",str);
					Strings.Concat(str,strNum,str);

					TRACE("creating file...");
					t := Kernel.GetTicks();
					file := Files.New(str);
					t := Kernel.GetTicks() - t;
					TRACE("created file",t);

					TRACE("registering the created file...");
					t := Kernel.GetTicks();
					Files.Register(file);
					t := Kernel.GetTicks() - t;
					TRACE("registered the file",t);

					Files.OpenWriter(fw,file,0);
					TRACE("started a new file part",id,fileName0,partNum,byteCount);
				END;
			END;

			IF fw.res # 0 THEN
				TRACE("TestFs writer",id,"stopped due to a writer error",fw.res);
			END;

			fw.Update;
			run := FALSE;
		END Loop;

	BEGIN{ACTIVE}
		Kernel.SetTimer(tStart,0);
		startByteCount := 0;

		Loop;

	FINALLY
		BEGIN{EXCLUSIVE}
			exited := TRUE;
		END;
	END Writer;

	(* High-level reader activity *)
	Reader = OBJECT
	VAR
		id: SIGNED32;
		file: Files.File;
		fr: Files.Reader;
		rndData: Random.Generator;
		byteCount: SIGNED64;
		run, exited: BOOLEAN;

		tStart: Kernel.MilliTimer;
		startByteCount: SIGNED64;

		fileName0: Files.FileName;
		partNum: SIGNED32;
		partByteCount: SIGNED32;

		PROCEDURE & InitReader(id: SIGNED32; CONST fileName: ARRAY OF CHAR);
		BEGIN
			SELF.id := id;
			file := Files.Old(fileName);
			ASSERT(file # NIL);
			Files.OpenReader(fr, file, 0);
			NEW(rndData);
			rndData.InitSeed(id);

			COPY(fileName,fileName0);
			partNum := 0;

			byteCount := 0;
			partByteCount := 0;

			run := TRUE;
		END InitReader;

		PROCEDURE Exit;
		BEGIN {EXCLUSIVE}
			run := FALSE;
			AWAIT(exited);
		END Exit;

		PROCEDURE Start;
		BEGIN {EXCLUSIVE}
			run := TRUE
		END Start;

		PROCEDURE Pause;
		BEGIN {EXCLUSIVE}
			run := FALSE
		END Pause;

		PROCEDURE Running (): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN run
		END Running;

		PROCEDURE Exited (): BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN exited
		END Exited;

		PROCEDURE Loop;
		VAR
			v: SIGNED32;
			strNum: ARRAY 16 OF CHAR;
			str: Files.FileName;
		BEGIN
			WHILE run & (fr.res = 0) DO
				fr.RawLInt(v);
				INC(partByteCount, SIZEOF(SIGNED32));
				INC(byteCount, SIZEOF(SIGNED32));
				ASSERT(v = rndData.Integer());

				IF partByteCount MOD 0x1000000 = 0 THEN
					Kernel.SetTimer(tStart,0);
					startByteCount := byteCount;
				END;

				IF partByteCount = 0x40000000 THEN (* 1GB parts *)
					partByteCount := 0;
					INC(partNum);
					file.Close;
					Strings.IntToStr(partNum,strNum);
					Strings.Concat(fileName0,".p",str);
					Strings.Concat(str,strNum,str);
					file := Files.Old(str);
					IF file = NIL THEN
						RETURN;
					END;
					Files.OpenReader(fr,file,0);
					TRACE("started a new file part",id,fileName0,partNum,byteCount);
				END;
			END;
		END Loop;

	BEGIN {ACTIVE}
		Kernel.SetTimer(tStart, 0);
		startByteCount := 0;

		Loop;
	FINALLY
		BEGIN {EXCLUSIVE}
			exited := TRUE;
		END;
	END Reader;

VAR
	writers: FoxBasic.List;
	readers: FoxBasic.List;

	(**
		Start id fileName fileSize ~
	*)
	PROCEDURE StartWriter*(ctx: Commands.Context);
	VAR
		id: SIGNED32;
		fileName: Files.FileName;
		fileSize: SIGNED32;
		w: Writer;
		i: SIGNED32;
	BEGIN{EXCLUSIVE}
		IF ~ctx.arg.GetInteger(id,FALSE) THEN ctx.result := 1; RETURN; END;
		IF ~ctx.arg.GetString(fileName) THEN ctx.result := 1; RETURN;END;
		IF ~ctx.arg.GetInteger(fileSize,FALSE) THEN fileSize := -1; END;

		i := 0;
		WHILE (i < writers.Length()) & (writers.Get(i)(Writer).id # id) DO
			INC(i);
		END;

		IF i < writers.Length() THEN
			ctx.error.String("TestFs writer with ID "); ctx.error.Int(id,0); ctx.error.String(" already running"); ctx.error.Ln;
			ctx.result := 1;
			RETURN;
		END;

		NEW(w,id,fileName,fileSize);

		writers.Add(w);

		ctx.out.String("Started TestFs writer with ID "); ctx.out.Int(id,0);
		ctx.out.String(", fileName='"); ctx.out.String(fileName);
		ctx.out.String("', fileSize="); ctx.out.Int(fileSize,0); ctx.out.Ln;
	END StartWriter;

	(* ID *)
	PROCEDURE StopWriter*(ctx: Commands.Context);
	VAR
		id: SIGNED32;
		i: SIGNED32;
	BEGIN{EXCLUSIVE}
		IF ~ctx.arg.GetInteger(id,FALSE) THEN ctx.result := 1; RETURN; END;

		i := 0;
		WHILE (i < writers.Length()) & (writers.Get(i)(Writer).id # id) DO
			INC(i);
		END;

		IF i < writers.Length() THEN
			writers.Get(i)(Writer).Exit;
			writers.RemoveByIndex(i);
			ctx.out.String("Stopped TestFs writer with ID "); ctx.out.Int(id,0); ctx.out.Ln;
		ELSE
			ctx.error.String("TestFs writer with ID "); ctx.error.Int(id,0); ctx.error.String(" not found"); ctx.error.Ln;
			ctx.result := 1;
			RETURN;
		END;
	END StopWriter;

	PROCEDURE DoReportWriter(id: SIGNED32; ctx: Commands.Context);
	VAR
		i: SIGNED32;
		w: Writer;
		speed: FLOAT32;
	BEGIN
		i := 0;
		WHILE (i < writers.Length()) & (writers.Get(i)(Writer).id # id) DO
			INC(i);
		END;

		IF i < writers.Length() THEN
			w := writers.Get(i)(Writer);
			speed := 1000.0 * FLOAT32(w.byteCount-w.startByteCount) / Kernel.Elapsed(w.tStart);
			ctx.out.String("byte count="); ctx.out.Int(w.byteCount,0); ctx.out.Ln;
			ctx.out.String("speed="); ctx.out.FloatFix(speed,0,5,0); ctx.out.String(" bytes/s"); ctx.out.Ln;
			ctx.out.String("status: ");
			IF w.Exited() THEN
				ctx.out.String("Finished");
			ELSIF w.Running() THEN
				ctx.out.String("Running");
			ELSE
				ctx.out.String("Paused");
			END;
			ctx.out.Ln;
		ELSE
			ctx.error.String("TestFs writer with ID "); ctx.error.Int(id,0); ctx.error.String(" not found"); ctx.error.Ln;
			ctx.result := Commands.CommandError;
		END;
	END DoReportWriter;

	(**
		ReportWriter id ~
	*)
	PROCEDURE ReportWriter*(ctx: Commands.Context);
	VAR
		id: SIGNED32;
	BEGIN{EXCLUSIVE}
		IF ~ctx.arg.GetInteger(id,FALSE) THEN
			ctx.result := Commands.CommandError;
			ctx.error.String("writer ID is not specified"); ctx.error.Ln;
			RETURN;
		END;

		DoReportWriter(id,ctx);
	END ReportWriter;

	PROCEDURE StartReader*(ctx: Commands.Context);
	VAR
		fileName: Files.FileName;
		r: Reader;
		id: SIGNED32;
		i: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF ~ctx.arg.GetInteger(id,FALSE) THEN ctx.result := 1; RETURN; END;
		IF ~ctx.arg.GetString(fileName) THEN ctx.result := 1; RETURN;END;

		WHILE (i < readers.Length()) & (readers.Get(i)(Reader).id # id) DO INC(i); END;
		IF i < readers.Length() THEN
			ctx.error.String("TestFs reader with ID ");
			ctx.error.Int(id, 0);
			ctx.error.String(" already running.");
			ctx.error.Ln;
			ctx.result := 1;
			RETURN;
		END;
		NEW(r, id, fileName);
		readers.Add(r);

		ctx.out.String("Added TestFs reader with ID ");
		ctx.out.Int(id, 0);
		ctx.out.String(", fileName='");
		ctx.out.String(fileName);
		ctx.out.String("'");
		ctx.out.Ln;
	END StartReader;

	PROCEDURE StopReader*(ctx: Commands.Context);
	VAR
		r: Reader;
		id: SIGNED32;
		i: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF ~ctx.arg.GetInteger(id, FALSE) THEN ctx.result := 1; RETURN; END;

		WHILE (i < readers.Length()) & (readers.Get(i)(Reader).id # id) DO INC(i); END;
		IF i = readers.Length() THEN
			ctx.error.String("TestFs reader with ID ");
			ctx.error.Int(id, 0);
			ctx.error.String(" is not running");
			ctx.error.Ln;
			ctx.result := 1;
			RETURN;
		END;

		r := readers.Get(i)(Reader);
		r.Exit;
		readers.RemoveByIndex(i);

		ctx.out.String("TestFs reader ");
		ctx.out.Int(id, 0);
		ctx.out.String(" stopped");
		ctx.out.Ln;
	END StopReader;

	PROCEDURE DoReportReader(id: SIGNED32; ctx: Commands.Context);
	VAR
		r: Reader;
		i: SIGNED32;
		speed: FLOAT64;
	BEGIN
		WHILE (i < readers.Length()) & (readers.Get(i)(Reader).id # id) DO INC(i); END;
		IF i < readers.Length() THEN
			r := readers.Get(i)(Reader);
			speed := 1000.0 * (r.byteCount-r.startByteCount) / Kernel.Elapsed(r.tStart);
			ctx.out.String("byte count="); ctx.out.Int(r.byteCount, 0); ctx.out.Ln;
			ctx.out.String("speed="); ctx.out.FloatFix(speed,0,5,0); ctx.out.String(" bytes/s"); ctx.out.Ln;
			ctx.out.String("status: ");
			IF r.Exited() THEN
				ctx.out.String("Finished");
			ELSIF r.Running() THEN
				ctx.out.String("Running");
			ELSE
				ctx.out.String("Paused");
			END;
			ctx.out.Ln;
		ELSE
			ctx.error.String("TestFs reader with ID "); ctx.error.Int(id,0); ctx.error.String(" not found"); ctx.error.Ln;
			ctx.result := Commands.CommandError;
			ctx.result := Commands.CommandError;
			RETURN;
		END;
	END DoReportReader;

	PROCEDURE ReportReader*(ctx: Commands.Context);
	VAR
		id: SIGNED32;
	BEGIN {EXCLUSIVE}
		IF ~ctx.arg.GetInteger(id,FALSE) THEN
			ctx.result := Commands.CommandError;
			ctx.error.String("reader ID is not specified"); ctx.error.Ln;
			RETURN;
		END;

		DoReportReader(id,ctx);
	END ReportReader;

	PROCEDURE Report*(ctx: Commands.Context);
	VAR
		w: Writer;
		r: Reader;
		i: SIGNED32;
	BEGIN{EXCLUSIVE}
		IF writers.Length() # 0 THEN
			FOR i := 0 TO writers.Length()-1 DO
				w := writers.Get(i)(Writer);
				ctx.out.String("writer (ID="); ctx.out.Int(w.id,0); ctx.out.String("):"); ctx.out.Ln;
				DoReportWriter(w.id,ctx);
				ctx.out.Ln;
			END;
		ELSE
			ctx.out.String("no TestFs writer is running"); ctx.out.Ln;
		END;

		IF readers.Length() # 0 THEN
			FOR i := 0 TO readers.Length()-1 DO
				r := readers.Get(i)(Reader);
				ctx.out.String("reader (ID="); ctx.out.Int(r.id,0); ctx.out.String("):"); ctx.out.Ln;
				DoReportReader(r.id,ctx);
				ctx.out.Ln;
			END;
		ELSE
			ctx.out.String("no TestFs reader is running"); ctx.out.Ln;
		END;
	END Report;

BEGIN
	NEW(writers,8);
	NEW(readers, 8);
END TestFs.

SystemTools.DoCommands
	TFTPServer.Start ~
	OEB.NewServer --type=Auto
		PLAN
			setsource TFTP 10.3.34.188
			mount A2 SD0 3
			load A2.Bin a2
			load build/TestFs.Gof t
			deploy t file A2:TestFs.Gof
			setinput auto.txt
		END
	~
	(*OEB.NewServer --type=Interactive ~*)
	OEB.NewInterface --type=Udp --server=0 ~
	OEB.Server --start --all ~
	OEB.Interface --start --all --server=0 ~
~
SystemTools.DoCommands
	TFTPServer.Start ~
	OEB.NewServer --type=Interactive ~
	OEB.NewInterface --type=Udp --server=0 ~
	OEB.Server --start --all ~
	OEB.Interface --start --all --server=0 ~
~

StaticLinker.Link --fileName=A2.Bin --displacement=100000H -a --path=build/
	Runtime Initializer Platform FPE64 ARMRuntime Trace BootConfig Uart Machine Heaps Modules Objects Kernel KernelLog Plugins
	Streams Pipes Commands Reals Clock Dates Strings Files Disks Reflection TrapWriters Traps Locks Options PsConfig SdEnvironment
	Sd SdDisks SdControllers Caches DiskVolumes DiskFS BitSets StringPool ObjectFile Diagnostics GenericLinker GenericLoader
	BootConsole
~

OEB.Command --server=0 --id=0
	setsource TFTP 10.3.34.188
	mount A2 SD0 3
	load A2.Bin a2
	save a2
	setinput auto.txt
~
	save a2
~

OEB.Command --server=0 --id=0
	setsource TFTP 10.3.34.188
	mount A2 SD0 3
	deployfile build/TestFs.Gof A2:TestFs.Gof
~

OEB.Command --server=0 --id=0
	start
~

OEB.Command --server=0 --id=0
	setinput auto.txt
~

OEB.Command --server=0 --id=0
	reset
~

OEB.Interface --show --all --server=0 ~
OEB.Server --show --all ~
OEB.Session --show --all ~
OEB.Server --kill --all ~
SystemTools.FreeDownTo OEBInterfaces ~
SystemTools.FreeDownTo UDP ~

mount DATA AosFS SD0#4 '|' N

TestFs.StartWriter 1234567 DATA:TestFs-1234567.dat 1000000000
TestFs.StartWriter 7654321 DATA:TestFs-7654321.dat 1000000000


TestFs.StartReader 1234567 DATA:TestFs-123457.dat 1000000000
TestFs.StartReader 7654321 DATA:TestFs-7654321.dat

TestFs.ReportWriter 1234567
TestFs.ReportWriter 7654321
TestFs.ReportReader 1234567
TestFs.ReportReader 1234567
asd