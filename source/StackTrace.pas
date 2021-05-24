unit StackTrace;

{
  Enables the collection and output of stack traces in Delphi code.

  For readable and sensible results, *current* PDB files must exist in the same directory. 

  Anders Melander's map2pdb.exe can be used for this:
	https://bitbucket.org/anders_melander/map2pdb/src/master/

}

{$include CompilerOptions.inc}

interface

uses
  WinSlimLock,
  DbgHelp;

type
  // Supports the acquisition of stack traces with build-in Windows functionality. 
  // The methods is also the basis for the private structure TExceptionHelp, which enables
  // stack traces to be obtained for thrown exceptions. 
  TStackTraceHlp = record
  strict private
	type
	  self = TStackTraceHlp;
	  CONTEXT = DbgHelp.CONTEXT;
	  PCONTEXT = ^CONTEXT;
	  SYMBOL_INFO = DbgHelp.SYMBOL_INFO;

	  TFrameInfo = record
		ModuleName: string;
		FuncName: string;
		SrcFilename: string;
		SrcLineNo: uint32;
		function ToString: string;
	  end;

	const
	  FProcess = THandle(-1);	// = Windows.GetCurrentProcess
	  FThread = THandle(-2);	// = Windows.GetCurrentThread
	class var
	  FInitDone: boolean;
	  FLock: TSlimRWLock;

	class procedure InitDbgHelp; static;
	class function ProcessFrame(VirtualAddr: DWORD64): TFrameInfo; static;
	class function GetModuleFilename(hModule: HINST): string; static;
  private
	type
	  TAddrs = array of DWORD64;

	//class procedure FiniDbgHelp; static;
	class procedure DoSetupContext(var Ctx: CONTEXT); static;
	class function DoGetStackTrace(SkipFrames: integer; Ctx: PCONTEXT): TAddrs; static;
	class function InterpretStackTrace(const Addrs: TAddrs): string; static;
  public
	class function GetStackTrace: string; static;
  end;


{############################################################################}
implementation
{############################################################################}

uses
  Types,
  Windows,
  SysUtils;

const
  CrLf = #13#10;

threadvar
  gThreadContext: DbgHelp.CONTEXT;

type
  TContextHlp = record helper for DbgHelp.CONTEXT
  public
	procedure SetNull;
  end;


 //===================================================================================================================
 //===================================================================================================================
procedure MyAssert(Cond: boolean); inline;
begin
  Assert(Cond);
end;


 //===================================================================================================================
 //===================================================================================================================
procedure ZeroMem(var Mem; Size: integer); inline;
begin
  System.FillChar(Mem, Size, 0);
end;


{ TContextHlp }

 //===================================================================================================================
 //===================================================================================================================
procedure TContextHlp.SetNull;
begin
  ZeroMem(self, sizeof(self));
end;


{ TStackTraceHlp.TFrameInfo }

 //===================================================================================================================
 // Returns a line of text for this stack frame.
 //===================================================================================================================
function TStackTraceHlp.TFrameInfo.ToString: string;
begin
  if self.SrcLineNo = 0  then
	Result := SysUtils.Format('  %s%s' + CrLf, [self.ModuleName, self.FuncName])
  else
	Result := SysUtils.Format('  %s%s in %s (Line %u)' + CrLf, [self.ModuleName, self.FuncName, self.SrcFilename, self.SrcLineNo]);
end;


{ TStackTraceHlp }

 //===================================================================================================================
 // Initializes the DbgHelp DLL for this process.
 // Must run in lock, as DbgHelp functions are not thread-safe.
 // Does not throw exceptions.
 //===================================================================================================================
class procedure TStackTraceHlp.InitDbgHelp;
begin
  if not FInitDone then begin
	// Needs "symsrv.dll": 'srv*c:\Entwicklung\WindowsSymbols*https://msdl.microsoft.com/download/symbols'
	MyAssert(DbgHelp.SymInitialize(FProcess, PChar(SysUtils.ExtractFileDir(self.GetModuleFilename(0))), true));
	FInitDone := true;
	DbgHelp.SymSetOptions(SYMOPT_LOAD_LINES or SYMOPT_DEFERRED_LOADS);
  end;
end;


{
 //===================================================================================================================
 // Must run in lock, as DbgHelp functions are not thread-safe.
 // Does not throw exceptions.
 //===================================================================================================================
class procedure TStackTraceHlp.FiniDbgHelp;
begin
  if FInitDone then begin
	FInitDone := false;
	MyAssert(DbgHelp.SymCleanup(FProcess));
  end;
end;
}


 //===================================================================================================================
 // Returns the full path to the loaded module (EXE oder DLL) <hModule>.
 // Does not throw exceptions.
 //===================================================================================================================
class function TStackTraceHlp.GetModuleFilename(hModule: HINST): string;
var
  Len: DWORD;
  Buffer: array [0..MAX_PATH] of char;
begin
  Len := System.Length(Buffer);
  if Windows.GetModuleFileName(hModule, Buffer, Len) >= Len then
	Result := '???'
  else
	Result := Buffer;
end;


 //===================================================================================================================
 // Captures the stack for the CPU context <Ctx>. (The stack must still cover the location of <Ctx>.)
 // Does not throw exceptions.
 //===================================================================================================================
class function TStackTraceHlp.DoGetStackTrace(SkipFrames: integer; Ctx: PCONTEXT): TAddrs;
const
  MachineType = {$ifdef Win64} IMAGE_FILE_MACHINE_AMD64 {$else} IMAGE_FILE_MACHINE_I386 {$endif};
var
  Frame: STACKFRAME64;
  cnt: integer;
begin
  // DbgHelp functions are not thread-safe:
  FLock.AcquireExclusive;
  try

	// A process that calls SymInitialize should not call it again unless it calls SymCleanup first.
	self.InitDbgHelp;

	ZeroMem(Frame, sizeof(Frame));
	Frame.AddrPC.Mode    := AddrModeFlat;
	Frame.AddrFrame.Mode := AddrModeFlat;
	Frame.AddrStack.Mode := AddrModeFlat;

	{$ifdef Win64}
	Frame.AddrPC.Offset    := Ctx.Rip;
	Frame.AddrFrame.Offset := Ctx.Rbp;
	Frame.AddrStack.Offset := Ctx.Rsp;
	{$else}
	Frame.AddrPC.Offset    := Ctx.Eip;
	Frame.AddrFrame.Offset := Ctx.Ebp;
	Frame.AddrStack.Offset := Ctx.Esp;
	{$endif}

	Result := nil;
	cnt := -SkipFrames;

	// ContextRecord: This context may be modified,
	while DbgHelp.StackWalk64(MachineType, FProcess, FThread, Frame, Ctx^, nil, DbgHelp.SymFunctionTableAccess64, DbgHelp.SymGetModuleBase64, nil) do begin
	  if cnt >=  0 then begin
		SetLength(Result, cnt + 1);
		Result[cnt] := Frame.AddrPC.Offset;
	  end;
	  inc(cnt);
	end;

  finally
	FLock.ReleaseExclusive;
  end;
end;


 //===================================================================================================================
 // Provides information on the code address <VirtualAddr> via Windows' built-in mechanisms. The information improves
 // drastically if there are suitable pdb files for the exe and for the DLLs. 
 // Does not throw exceptions.
 //===================================================================================================================
class function TStackTraceHlp.ProcessFrame(VirtualAddr: DWORD64): TFrameInfo;
const
  MaxSymbolLen = 254;
var
  SymOffset: DWORD64;
  LineOffset: DWORD;
  Symbol: record
	case byte of
	0: (s: DbgHelp.SYMBOL_INFO);
	1: (b: array [0..sizeof(SYMBOL_INFO) - 2 + MaxSymbolLen * sizeof(WideChar)] of byte);
  end;
  Line: IMAGEHLP_LINE64;
begin
  Assert(FInitDone);

  Finalize(Result);
  ZeroMem(Result, sizeof(Result));

  ZeroMem(Symbol, sizeof(Symbol));
  Symbol.s.SizeOfStruct := sizeof(Symbol.s);
  Symbol.s.MaxNameLen := MaxSymbolLen;	// max name length excluding the null char

  // DbgHelp functions are not thread-safe:
  FLock.AcquireExclusive;
  try

	if not DbgHelp.SymFromAddr(FProcess, VirtualAddr, SymOffset, Symbol.s) then begin
	  Result.FuncName := '0x' + SysUtils.IntToHex(VirtualAddr, 2 * sizeof(pointer));;
	  exit;
	end;

	SetString(Result.FuncName, Symbol.s.Name, Symbol.s.NameLen);

	if Symbol.s.ModBase <> 0 then
	  Result.ModuleName := SysUtils.ExtractFilename(self.GetModuleFilename(HINST(Symbol.s.ModBase))) + ': ';

	ZeroMem(Line, sizeof(Line));
	Line.SizeOfStruct := sizeof(Line);

	if DbgHelp.SymGetLineFromAddr64(FProcess, VirtualAddr, LineOffset, Line) then begin
	  Result.SrcFilename := Line.FileName;
	  Result.SrcLineNo := Line.LineNumber;
	end
	else if SymOffset <> 0 then begin
	  Result.FuncName := Result.FuncName + ' + 0x' + SysUtils.IntToHex(SymOffset, 1)
	end;

  finally
	FLock.ReleaseExclusive;
  end;
end;


 //===================================================================================================================
 // Returns textual representation of <Addrs>.
 // Does not throw exceptions.
 //===================================================================================================================
class function TStackTraceHlp.InterpretStackTrace(const Addrs: TAddrs): string;
var
  Addr: DWORD64;
begin
  Result := '';
  for Addr in Addrs do begin
	Result := Result + self.ProcessFrame(Addr).ToString;
  end;
end;


 //===================================================================================================================
 // Initializes <Ctx> for the current thread. It is particularly important to set EIP / RIP to an address within the
 // body (!) of the calling function. 
 //===================================================================================================================
class procedure TStackTraceHlp.DoSetupContext(var Ctx: CONTEXT);
asm
  {$ifdef Win64}

  // RCX = @Ctx

  .NOFRAME
  MOV Ctx.ContextFlags, CONTEXT_CONTROL or CONTEXT_INTEGER
  // for CONTEXT_CONTROL:
  MOV RDX, [RSP]		// top element contains return address
  MOV Ctx.&Rip, RDX
  MOV Ctx.&Rbp, RBP		// unclear if used as it is not part of the x64 calling convention
  LEA RDX, [RSP + 8]	// make .RSP consistent to .RBP
  MOV Ctx.&Rsp, RDX     // := RSP + sizeof(return address)
  // CONTEXT_INTEGER seams to cover Rbp and Rsp

  {$else}

  // EAX = @Ctx

  MOV Ctx.ContextFlags, CONTEXT_CONTROL
  // for CONTEXT_CONTROL:
  MOV EDX, [ESP]		// top element contains return address
  MOV Ctx.&Eip, EDX
  MOV Ctx.&Ebp, EBP
  LEA EDX, [ESP + 4]	// make .ESP consistent to .EBP
  MOV Ctx.&Esp, EDX     // := ESP + sizeof(return address)

  {$endif}
end;


 //===================================================================================================================
 // For usage by application code, outside of the internal Delphi or Windows exception handling.
 //===================================================================================================================
{$StackFrames on}
class function TStackTraceHlp.GetStackTrace: string;
var
  Ctx: ^CONTEXT;
begin
  Ctx := @gThreadContext;
  Ctx.SetNull;
  self.DoSetupContext(Ctx^);
  Result := self.InterpretStackTrace(self.DoGetStackTrace(1, Ctx));
end;
{$StackFrames off}


type
  // Provides types and methods to hook into the Delphi and Windows exception mechanisms in order to
  // obtain stack traces of exceptions. 
  TExceptionHelp = record
  strict private
	const
	  cDelphiException    = $0EEDFADE;	// from System.pas
	type
	  self = TExceptionHelp;

	  PFrames = ^TFrames;
	  TFrames = record
		Addrs: TStackTraceHlp.TAddrs;
	  end;

	class var
	  FHandlerHandle: pointer;

	class function GetExceptionStackInfo(P: PExceptionRecord): pointer; static;
	class procedure CleanupStackInfo(Info: Pointer); static; static;
	class function GetStackInfoString(Info: Pointer): string; static;

	class function OsExceptionHandler(Info: PEXCEPTION_POINTERS): LONG; stdcall; static;
  public
	class procedure Init; static;
	class procedure Fini; static;
  end;


{ TExceptionHelp }

 //===================================================================================================================
 //===================================================================================================================
class procedure TExceptionHelp.Init;
begin
  SysUtils.Exception.GetExceptionStackInfoProc := self.GetExceptionStackInfo;
  SysUtils.Exception.CleanupStackInfoProc := self.CleanupStackInfo;
  SysUtils.Exception.GetStackInfoStringProc := self.GetStackInfoString;

  // hook into Windows exception handling:
  FHandlerHandle := DbgHelp.AddVectoredExceptionHandler(1, OsExceptionHandler);
  Assert(FHandlerHandle <> nil);
end;


 //===================================================================================================================
 //===================================================================================================================
class procedure TExceptionHelp.Fini;
begin
  MyAssert(DbgHelp.RemoveVectoredExceptionHandler(FHandlerHandle) <> 0);

  SysUtils.Exception.GetExceptionStackInfoProc := nil;
  // Release should remain possible: SysUtils.Exception.CleanupStackInfoProc 
  SysUtils.Exception.GetStackInfoStringProc := nil;
end;


 //===================================================================================================================
 // Is called for every exception in the process and, in the case of Windows-generated exceptions, provides exact
 // information about the point at which the exception occurred. 
 // The handler should not call functions that acquire synchronization objects or allocate memory, because this can cause problems.
 //===================================================================================================================
class function TExceptionHelp.OsExceptionHandler(Info: PEXCEPTION_POINTERS): LONG;
begin
  if Info.ExceptionRecord.ExceptionCode <> cDelphiException then
	gThreadContext := Info.ContextRecord^
  else
	gThreadContext.ContextFlags := 0;

  Result := 0; // EXCEPTION_CONTINUE_SEARCH
end;


 //===================================================================================================================
 // Hook for Exception.GetExceptionStackInfoProc: Returns a TFrames record as the result, which the Delphi RTL then
 // stores in the exception. 
 // Is called by the RTL when:
 // - In the case of Delphi's own exceptions ("raise" statement): Before calling the Windows exception mechanism and thus
 //   before OsExceptionHandler.
 // - At Windows-Exception (z.B. Div-by-zero): As a reaction to the Windows exception and thus after OsExceptionHandler. 
 //===================================================================================================================
class function TExceptionHelp.GetExceptionStackInfo(P: PExceptionRecord): pointer;
var
  Ctx: ^DbgHelp.CONTEXT;
  SkipFrames: integer;
begin
  // gThreadContext is valid if a native Windows exception is handled (Division-by-Zero, Access Violation):
  Ctx := @gThreadContext;
  SkipFrames := 0;

  if p.ExceptionCode = cDelphiException then begin
	// Delphi "raise" statement: System._RaiseExcept: Creates the Exception object, before Windows.RaiseException
	// is called => must construct a suitable Context:
	Ctx.SetNull;
	TStackTraceHlp.DoSetupContext(Ctx^);
	{$ifdef Win64}
	SkipFrames := 5;
	{$else}
	SkipFrames := 2;
(*
	// System.pas, procedure _RaiseExcept, put the registers of the exception point as 7 arguments into ExceptionInformation:
	Assert(p.NumberParameters = 7);
	Ctx.ContextFlags := CONTEXT_CONTROL;
	Ctx.Eip := DWORD(p.ExceptionAddress);
	Ctx.Esp := DWORD(p.ExceptionInformation[6]);
	Ctx.Ebp := DWORD(p.ExceptionInformation[5]);
*)
	{$endif}
  end;

  Assert(Ctx.ContextFlags <> 0);

  System.New(PFrames(Result));
  PFrames(Result).Addrs := TStackTraceHlp.DoGetStackTrace(SkipFrames, Ctx);

  Ctx.ContextFlags := 0;
end;


 //===================================================================================================================
 // Hook for Exception.CleanupStackInfoProc: Releases <Info>.
 //===================================================================================================================
class procedure TExceptionHelp.CleanupStackInfo(Info: Pointer);
begin
  // Bug in Delphi 2009, SysUtils.pas, Zeile 17891, DoneExceptions:
  //   InvalidPointer.*Free* should be *FreeInstance* (as before in OutOfMemory.FreeInstance)
  // => need to test for nil:
  if Info <> nil then
	System.Dispose(PFrames(Info));
end;


 //===================================================================================================================
 // Hook for Exception.GetStackInfoStringProc: Generates text from <Info>.
 //===================================================================================================================
class function TExceptionHelp.GetStackInfoString(Info: Pointer): string;
begin
  Result := TStackTraceHlp.InterpretStackTrace(PFrames(Info).Addrs);
end;


initialization
  TExceptionHelp.Init;
finalization
  TExceptionHelp.Fini;
end.

