unit StackTrace;

{
  Enables the collection and output of stack traces in Delphi code.

  For readable and sensible results, *current* PDB files must exist in the same directory.

  Anders Melander's map2pdb.exe can be used for this:
	https://bitbucket.org/anders_melander/map2pdb/src/master/

  Notes:

  As the Delphi runtime library handles things not consistently and contains bugs (see some of the comments in the code),
  I don't know if this works with other Delphi versions as well. Please use a memory leak detector to verify the behavior.

  Generally, the 64bit compiler and RTL fixes a few things, as exception reraising now always reuses the original exception
  object and it also generates source-line infos for the main part of the dpr file (the lines between "begin" and "end.").

  The 32bit compiler and RTL makes it nearly impossible to get the stacktrace from an non-delphi exception that is reraised:
  For some reason, the original exception object is released by the RTL and then a new one is created, but we still need the
  stackinfo from the original object which is now gone. It is not possible to recreate it. So for now, I just reattach the
  very last stackinfo, but depending on other exceptions thrown and catched between the original point and the reraise point,
  it may be no longer the correct one.

  To get notifications on DLL unloading, the Windows function LdrRegisterDllNotification is used, which  may change on
  later Windows releases (unlikely). But there is no alternative.
}

{$include LibOptions.inc}

interface

uses
  Windows,
  WinSlimLock,
  DbgHelp;

type
  // Supports the acquisition of stack traces with build-in Windows functionality.
  // The methods is also the basis for the private structure TExceptionHelp, which is used to capture
  // stack traces when exceptions are thrown.
  TStackTraceHlp = record
  private
	type
	  PAddr = ^TAddr;
	  TAddr = DWORD_PTR;
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
	  FLock: TSlimRWLock;		// lock around all DbgHelp functions
	  FHandlerCookie: pointer;	// LdrRegisterDllNotification handle
	  FInitDone: boolean;		// state of DbgHelp regarding SymInitialize
	  FDoReinit: boolean;		// set to true when a DLL was unloaded

	class procedure InitSyms; static;
	class function ProcessFrame(VirtualAddr: TAddr): TFrameInfo; static;
	class function GetModuleFilename(hModule: HINST): string; static;

	class function GetFuncPtr(FuncName: PAnsiChar): pointer; static;
	class procedure OsDllNotification(Reason: ULONG; Data: pointer; Context: pointer); stdcall; static;
  private
	class procedure Init; static;
	class procedure Fini; static;
	class procedure FiniSyms; static;
	class procedure DoSetupContext(var Ctx: CONTEXT); static;
	class function DoGetStackTrace(var Ctx: CONTEXT; SkipFrames: uint32; out Addrs: array of TAddr): uint32; static;
	class function InterpretStackTrace(const Addrs: array of TAddr; Count: uint32): string; static;
  public
	class function GetStackTrace: string; static;
  end;


{############################################################################}
implementation
{############################################################################}

uses
  Types,
  SysUtils;

type
  TAddr = TStackTraceHlp.TAddr;

  TContextHlp = record helper for DbgHelp.CONTEXT
  strict private
	function GetIP: TAddr; inline;
	function GetSP: TAddr; inline;
	function GetBP: TAddr; inline;
	procedure SetIP(Value: TAddr); inline;
	procedure SetSP(Value: TAddr); inline;
	procedure SetBP(Value: TAddr); inline;
  public
	procedure SetNull; inline;
	property IP: TAddr read GetIP write SetIP;
	property SP: TAddr read GetSP write SetSP;
	property BP: TAddr read GetBP write SetBP;
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


 //===================================================================================================================
 //===================================================================================================================
function TContextHlp.GetIP: TAddr;
begin
  Result := {$ifdef Win64} self.Rip {$else} self.Eip {$endif};
end;


 //===================================================================================================================
 //===================================================================================================================
function TContextHlp.GetSP: TAddr;
begin
  Result := {$ifdef Win64} self.Rsp {$else} self.Esp {$endif};
end;


 //===================================================================================================================
 //===================================================================================================================
function TContextHlp.GetBP: TAddr;
begin
  Result := {$ifdef Win64} self.Rbp {$else} self.Ebp {$endif};
end;


 //===================================================================================================================
 //===================================================================================================================
procedure TContextHlp.SetIP(Value: TAddr);
begin
  {$ifdef Win64} self.Rip {$else} self.Eip {$endif} := Value;
end;


 //===================================================================================================================
 //===================================================================================================================
procedure TContextHlp.SetSP(Value: TAddr);
begin
  {$ifdef Win64} self.Rsp {$else} self.Esp {$endif} := Value;
end;


 //===================================================================================================================
 //===================================================================================================================
procedure TContextHlp.SetBP(Value: TAddr);
begin
  {$ifdef Win64} self.Rbp {$else} self.Ebp {$endif} := Value;
end;


{ TStackTraceHlp.TFrameInfo }

 //===================================================================================================================
 // Returns a line of text for this stack frame.
 //===================================================================================================================
function TStackTraceHlp.TFrameInfo.ToString: string;
begin
  if self.SrcLineNo = 0  then
	Result := SysUtils.Format('%s%s', [self.ModuleName, self.FuncName])
  else
	Result := SysUtils.Format('%s%s in %s (Line %u)', [self.ModuleName, self.FuncName, self.SrcFilename, self.SrcLineNo]);
end;


{ TStackTraceHlp }

 //===================================================================================================================
 // Setup for getting stack traces on Delphi exceptions.
 //===================================================================================================================
class procedure TStackTraceHlp.Init;
var
  RegisterFunc: TLdrRegisterDllNotification;
begin
  // registering to get DLL unload notifications (may not work in future Windows versions, but there is nothing else!):
  RegisterFunc := self.GetFuncPtr('LdrRegisterDllNotification');
  if Assigned(RegisterFunc) then
	MyAssert(RegisterFunc(0, self.OsDllNotification, nil, FHandlerCookie) = STATUS_SUCCESS);
end;


 //===================================================================================================================
 // Teardown for getting stack traces on Delphi exceptions.
 //===================================================================================================================
class procedure TStackTraceHlp.Fini;
var
  UnregisterFunc: TLdrUnregisterDllNotification;
begin
  if Assigned(FHandlerCookie) then begin
	UnregisterFunc := self.GetFuncPtr('LdrUnregisterDllNotification');
	MyAssert(UnregisterFunc(FHandlerCookie) = STATUS_SUCCESS);
  end;
end;


 //===================================================================================================================
 // Initializes the DbgHelp DLL for this process.
 // Must run in lock, as DbgHelp functions are not thread-safe.
 // Does not throw exceptions.
 //===================================================================================================================
class procedure TStackTraceHlp.InitSyms;
begin
  // address space of an unloaded DLL may be reused (e.g. dynamic plug-ins) => reinitialize DbgHelp's symbol cache:
  if FDoReinit then begin
	FDoReinit := false;
	self.FiniSyms;
  end;

  // A process that calls SymInitialize should not call it again unless it calls SymCleanup first.
  if not FInitDone then begin
	// Needs "symsrv.dll": 'srv*c:\WindowsSymbols*https://msdl.microsoft.com/download/symbols'
	MyAssert(DbgHelp.SymInitialize(FProcess, PChar(SysUtils.ExtractFileDir(self.GetModuleFilename(0))), true));
	FInitDone := true;
	DbgHelp.SymSetOptions(SYMOPT_LOAD_LINES or SYMOPT_DEFERRED_LOADS);
  end;
end;


 //===================================================================================================================
 // Must run in lock, as DbgHelp functions are not thread-safe.
 // Does not throw exceptions.
 //===================================================================================================================
class procedure TStackTraceHlp.FiniSyms;
begin
  if FInitDone then begin
	FInitDone := false;
	MyAssert(DbgHelp.SymCleanup(FProcess));
  end;
end;


 //===================================================================================================================
 // Get pointer of function in ntdll.dll. Returns nil if unavaiable.
 //===================================================================================================================
class function TStackTraceHlp.GetFuncPtr(FuncName: PAnsiChar): pointer;
begin
  Result := Windows.GetProcAddress(Windows.LoadLibrary('ntdll.dll'), FuncName);
  Assert(Assigned(Result));
end;


 //===================================================================================================================
 // Is called on loading and unloading of DLLs in the process. DLL unloading can occur at the very same time some thread
 // is taking a stack trace, but this thread should not have addresses of an unloading/unloaded DLL in its call stack.
 //===================================================================================================================
class procedure TStackTraceHlp.OsDllNotification(Reason: ULONG; Data: pointer; Context: pointer);
begin
  if Reason = LDR_DLL_NOTIFICATION_REASON_UNLOADED then
	FDoReinit := true;
end;


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
class function TStackTraceHlp.DoGetStackTrace(var Ctx: CONTEXT; SkipFrames: uint32; out Addrs: array of TAddr): uint32;
const
  MachineType = {$ifdef Win64} IMAGE_FILE_MACHINE_AMD64 {$else} IMAGE_FILE_MACHINE_I386 {$endif};
var
  Frame: STACKFRAME64;
begin
  // DbgHelp functions are not thread-safe:
  FLock.AcquireExclusive;
  try

	self.InitSyms;

	ZeroMem(Frame, sizeof(Frame));
	Frame.AddrPC.Mode    := AddrModeFlat;
	Frame.AddrFrame.Mode := AddrModeFlat;
	Frame.AddrStack.Mode := AddrModeFlat;
	Frame.AddrPC.Offset    := Ctx.IP;
	Frame.AddrFrame.Offset := Ctx.BP;
	Frame.AddrStack.Offset := Ctx.SP;

	Result := 0;

	// ContextRecord: This context may be modified,
	while (int32(Result) <= System.High(Addrs))
	 and DbgHelp.StackWalk64(MachineType, FProcess, FThread, Frame, Ctx, nil, DbgHelp.SymFunctionTableAccess64, DbgHelp.SymGetModuleBase64, nil)
	do begin
	  if SkipFrames > 0 then begin
		dec(SkipFrames);
		continue;
	  end;
	  Addrs[Result] := Frame.AddrPC.Offset;
	  inc(Result);
	end;

  finally
	FLock.ReleaseExclusive;
  end;
end;


 //===================================================================================================================
 // Provides information on the code address <VirtualAddr> via Windows' built-in mechanisms. The information improves
 // drastically if there are suitable pdb files for the EXE and DLLs.
 // Does not throw exceptions.
 //===================================================================================================================
class function TStackTraceHlp.ProcessFrame(VirtualAddr: TAddr): TFrameInfo;
const
  MaxSymbolLen = 254;
var
  SymOffset: DWORD64;
  LineOffset: DWORD;
  Symbol: record
	case byte of
	0: (s: DbgHelp.SYMBOL_INFO);
	1: (b: array [0..sizeof(SYMBOL_INFO) - sizeof(char) + MaxSymbolLen * sizeof(char)] of byte);
  end;
  HaveSymbol: boolean;
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

	HaveSymbol := DbgHelp.SymFromAddr(FProcess, VirtualAddr, SymOffset, Symbol.s);

	if not HaveSymbol or (Symbol.s.ModBase = 0) then
	  Symbol.s.ModBase := DbgHelp.SymGetModuleBase64(FProcess, VirtualAddr);

	if Symbol.s.ModBase <> 0 then
	  Result.ModuleName := SysUtils.ExtractFilename(self.GetModuleFilename(HINST(Symbol.s.ModBase))) + ': ';

	if not HaveSymbol then begin
	  Result.FuncName := '0x' + SysUtils.IntToHex(VirtualAddr, 2 * sizeof(pointer));;
	  exit;
	end;

	SetString(Result.FuncName, Symbol.s.Name, Symbol.s.NameLen);

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
class function TStackTraceHlp.InterpretStackTrace(const Addrs: array of TAddr; Count: uint32): string;
var
  i: int32;
begin
  Result := '';
  for i := 0 to int32(Count) - 1 do begin
	if i <> 0 then Result := Result + #13#10;
	Result := Result + '  at ' + self.ProcessFrame(Addrs[i]).ToString;
  end;
end;


 //===================================================================================================================
 // Initializes <Ctx> for the current thread. It is particularly important to set EIP / RIP to an address within the
 // body(!) of the calling function.
 //===================================================================================================================
class procedure TStackTraceHlp.DoSetupContext(var Ctx: CONTEXT);
asm
  {$ifdef Win64}

  // RCX = @Ctx

  .NOFRAME
  MOV Ctx.ContextFlags, CONTEXT_CONTROL or CONTEXT_INTEGER
  // für CONTEXT_CONTROL:
  MOV RDX, [RSP]		// top element contains return address
  MOV Ctx.&Rip, RDX
  MOV Ctx.&Rbp, RBP		// unclear if used as it is not part of the x64 calling convention
  LEA RDX, [RSP + 8]	// make .RSP consistent to .RBP
  MOV Ctx.&Rsp, RDX     // := RSP + sizeof(return address)
  // CONTEXT_INTEGER seams to cover Rbp and Rsp

  {$else}

  // EAX = @Ctx

  MOV Ctx.ContextFlags, CONTEXT_CONTROL
  // für CONTEXT_CONTROL:
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
class function TStackTraceHlp.GetStackTrace: string;
var
  Ctx: DbgHelp.CONTEXT;
  Addrs: array [0..255] of TAddr;
  Count: uint32;
begin
  Ctx.SetNull;
  self.DoSetupContext(Ctx);
  Count := self.DoGetStackTrace(Ctx, 1, Addrs);
  Result := self.InterpretStackTrace(Addrs, Count);
end;


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
		Addrs: array [0..63] of TAddr;
		Count: uint32;
	  end;

	class var
	  FHandlerHandle: pointer;

	class function OsExceptionHandler(Info: PEXCEPTION_POINTERS): LONG; stdcall; static;

	class function GetExceptionStackInfo(P: PExceptionRecord): pointer; static;
	class procedure CleanupStackInfo(Info: Pointer); static; static;
	class function GetStackInfoString(Info: Pointer): string; static;

  private
	type
	  TOsExceptCtx = record
		IP: TAddr;
		SP: TAddr;
		BP: TAddr;
		{$ifndef Win64}
		Stack: TFrames;
		ValidCtx: boolean;
		{$endif}
	  end;

  public
	class procedure Init; static;
	class procedure Fini; static;
  end;

threadvar
  gOsExceptCtx: TExceptionHelp.TOsExceptCtx;


{ TExceptionHelp }

 //===================================================================================================================
 // Setup for getting stack traces on Delphi exceptions.
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
 // Teardown for getting stack traces on Delphi exceptions.
 //===================================================================================================================
class procedure TExceptionHelp.Fini;
begin
  MyAssert(DbgHelp.RemoveVectoredExceptionHandler(FHandlerHandle) <> 0);

  SysUtils.Exception.GetExceptionStackInfoProc := nil;
  //  Release should remain possible: SysUtils.Exception.CleanupStackInfoProc not cleared
  SysUtils.Exception.GetStackInfoStringProc := nil;
end;


 //===================================================================================================================
 // Is called for every exception in the process and, in the case of Windows-generated exceptions, provides exact
 // information about the point at which the exception occurred.
 // Is not called again when re-raising an exception.
 // The handler should not call functions that acquire synchronization objects or allocate memory, because this can cause problems.
 //===================================================================================================================
class function TExceptionHelp.OsExceptionHandler(Info: PEXCEPTION_POINTERS): LONG;
var
  Ctx: ^TOsExceptCtx;
begin
  if Info.ExceptionRecord.ExceptionCode <> cDelphiException then begin
	Ctx := @gOsExceptCtx;
	Ctx.IP := Info.ContextRecord.IP;
	Ctx.SP := Info.ContextRecord.SP;
	Ctx.BP := Info.ContextRecord.BP;
	{$ifndef Win64}
	Ctx.ValidCtx := true;
	{$endif}
  end;

  Result := 0; // EXCEPTION_CONTINUE_SEARCH
end;


 //===================================================================================================================
 // Hook for Exception.GetExceptionStackInfoProc: Returns a TStack record as the result, which the Delphi RTL then
 // stores in the exception.
 // Is called by the RTL:
 // - For Delphi's own exceptions ("raise" statement): Before calling the Windows exception mechanism and thus
 //   before OsExceptionHandler.
 // - For non-Delphi exception (i.e. Div-by-zero): As a reaction to the Windows exception and thus after OsExceptionHandler.
 // - For reraise ("raise" statement without argument): Without OsExceptionHandler being called.
 //
 // Win32: Reraise of Delphi exceptions:
 // The RTL keeps the exception objec created by the original "raise".
 //
 // Win32: Reraise of non-Delphi exceptions:
 // Idiotically, the RTL releases the original execption objekt and therefore the attached StackInfo (System.pas,
 //  _RaiseAgain, line 12524), instead of keeping and resuing it!
 // The CPU stack and gOsExceptCtx are outdated and therefore unusable at this point => We only can reuse the last
 // stackinfo generated for the address, which is not 100% reliable...
 //
 // Win64: Reraise: The original exception *code* is lost due to _RaiseAgain calling _RaiseAtExcept, which handles
 // reraised non-delphi exceptions the same as Delphi exception. But the original exception object is kept and reused,
 // so it's stackinfo is still available.
 //===================================================================================================================
{$ifdef Win64}

class function TExceptionHelp.GetExceptionStackInfo(p: PExceptionRecord): pointer;
var
  OsCtx: ^TOsExceptCtx;
  Ctx: DbgHelp.CONTEXT;
  SkipFrames: integer;
begin
  if TObject(p.ExceptObject) is EAbort then exit(nil);

  // Delphi 10.1 + Win64: Prevent memory leak, as also preserve the StackInfo from the original exception, by not
  // overwriting an already existing StackInfo object in the reraised exception object.
  if (TObject(P.ExceptObject) is Exception) and (Exception(P.ExceptObject).StackInfo <> nil) then
	exit(Exception(P.ExceptObject).StackInfo);

  if p.ExceptionCode = cDelphiException then begin
	// initial handling of a Delphi exception: System._RaiseExcept: Creates the Exception object, before
	// Windows.RaiseException is called => must construct a suitable Context:
	Ctx.SetNull;
	TStackTraceHlp.DoSetupContext(Ctx);
	SkipFrames := 5;
  end
  else begin
	// initial handling of a non-Delphi exception: OsCtx contains the data captured immediately before:
	Ctx.SetNull;
	Ctx.ContextFlags := CONTEXT_CONTROL or CONTEXT_INTEGER;
	OsCtx := @gOsExceptCtx;
	Ctx.IP := OsCtx.IP;
	Ctx.SP := OsCtx.SP;
	Ctx.BP := OsCtx.BP;
	SkipFrames := 0;
  end;

  System.GetMem(Result, sizeof(TFrames));
  PFrames(Result).Count := TStackTraceHlp.DoGetStackTrace(Ctx, SkipFrames, PFrames(Result).Addrs);
end;

{$else}

class function TExceptionHelp.GetExceptionStackInfo(p: PExceptionRecord): pointer;
var
  OsCtx: ^TOsExceptCtx;
  Ctx: DbgHelp.CONTEXT;
begin
  if TObject(p.ExceptObject) is EAbort then exit(nil);

  // case "raise System.AcquireExceptionObject": Prevent memory leak, as also preserve the StackInfo from the original
  // exception, by not overwriting an already existing StackInfo object in the reraised exception object.
  if (TObject(P.ExceptObject) is Exception) and (Exception(P.ExceptObject).StackInfo <> nil) then
	exit(Exception(P.ExceptObject).StackInfo);

  OsCtx := @gOsExceptCtx;

  if p.ExceptionCode = cDelphiException then begin
	// initial handling of a Delphi exception: System._RaiseExcept: Creates the Exception object, before
	// Windows.RaiseException is called => must construct a suitable Context:
	Ctx.SetNull;
	// System.pas, procedure _RaiseExcept, puts the registers of the exception point as 7 arguments into ExceptionInformation:
	Assert(p.NumberParameters = 7);
	Ctx.ContextFlags := CONTEXT_CONTROL;
	Ctx.IP := TAddr(p.ExceptionAddress);
	Ctx.SP := TAddr(p.ExceptionInformation[6]);
	Ctx.BP := TAddr(p.ExceptionInformation[5]);
  end
  else if OsCtx.ValidCtx then begin
	// initial handling of a non-Delphi exception: OsCtx contains the data captured immediately before:
	Ctx.SetNull;
	Ctx.ContextFlags := CONTEXT_CONTROL;
	Ctx.IP := OsCtx.IP;
	Ctx.SP := OsCtx.SP;
	Ctx.BP := OsCtx.BP;
  end
  else if OsCtx.IP = TAddr(p.ExceptionAddress) then begin
	// reraise of a non-Delphi exception: OsCtx does not match the current CPU stack, which no longer covers the original
	// point of exception => can only reuse the last stackinfo (hopefully still the right one):
	System.GetMem(Result, sizeof(TFrames));
	PFrames(Result)^ := OsCtx.Stack;
	exit;
  end
  else
	exit(nil);

  System.GetMem(Result, sizeof(TFrames));
  PFrames(Result).Count := TStackTraceHlp.DoGetStackTrace(Ctx, 0, PFrames(Result).Addrs);

  if p.ExceptionCode <> cDelphiException then begin
	// non-Delphi exception: Context is consumed now, save the generated stackinfo for possible reraise:
	OsCtx.ValidCtx := false;
	OsCtx.Stack := PFrames(Result)^;
  end;
end;
{$endif}


 //===================================================================================================================
 // Hook for Exception.CleanupStackInfoProc: Releases  <Info>.
 //===================================================================================================================
class procedure TExceptionHelp.CleanupStackInfo(Info: Pointer);
begin
  // Bug since Delphi 2009: SysUtils.pas, line 17891, DoneExceptions:
  //   InvalidPointer.*Free* should be *FreeInstance* (as a few lines before with OutOfMemory.FreeInstance)
  // => CleanupStackInfo is also called for the shared "InvalidPointer" object which has no StackInfo
  System.FreeMem(Info);
end;


 //===================================================================================================================
 // Hook for Exception.GetStackInfoStringProc: Generates text from <Info>.
 //===================================================================================================================
class function TExceptionHelp.GetStackInfoString(Info: Pointer): string;
begin
  if Info = nil then
	Result := 'n/a'
  else
	Result := TStackTraceHlp.InterpretStackTrace(PFrames(Info).Addrs, PFrames(Info).Count);
end;


initialization
  TStackTraceHlp.Init;
  TExceptionHelp.Init;
finalization
  TExceptionHelp.Fini;
  TStackTraceHlp.Fini;
end.
