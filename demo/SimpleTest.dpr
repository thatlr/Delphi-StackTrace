program SimpleTest;

{$include CompilerOptions.inc}

{$AppType Console}

{$R *.res}

uses
  //WinMemMgr,
  //MemTest,
  //CorrectLocale,
  Stacktrace,
  Windows,
  SysUtils,
  ComObj;		// sets System.SafeCallErrorProc in newer RTL versions (SafeCallErrorProc was set by SysUtils.pas in D2009!)


// IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE = $8000: Terminal server aware
// IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE = $40: Address Space Layout Randomization (ASLR) enabled
// IMAGE_DLLCHARACTERISTICS_NX_COMPAT = $100: Data Execution Prevention (DEP) enabled
{$SetPeOptFlags $8140}

// IMAGE_FILE_LARGE_ADDRESS_AWARE: may use heap/code above 2GB
{$SetPeFlags IMAGE_FILE_LARGE_ADDRESS_AWARE}


type
  // Exception with a valid Unicode name:
  Exceptionµ = class(Exception);


// since Windows 7:
function SetProcessPreferredUILanguages(dwFlags: DWORD; pwszLanguagesBuffer: PWideChar; pulNumLanguages: PULONG): BOOL; stdcall; external Windows.kernel32 name 'SetProcessPreferredUILanguages';


 //===================================================================================================================
 // Force a given language to be used for dynamically loaded (resource-based) texts, like Windows error message texts.
 // Note: Works only if the respective Windows language pack is installed.
 //===================================================================================================================
procedure SetLang;
const
  MUI_LANGUAGE_NAME = $8;		// use ISO language (culture) name convention
  LangNames: array [0..6] of WideChar = 'en-US'#0#0;
begin
  SetProcessPreferredUILanguages(MUI_LANGUAGE_NAME, LangNames, nil);
end;


 //===================================================================================================================
 // The compiler will generate code at the call site for this.
 //===================================================================================================================
procedure Something;
begin
end;


 //===================================================================================================================
 // Testing Delphi statement "raise Exception".
 //===================================================================================================================
procedure TestDelpiException;
var
  AcquiredException: TObject;
begin
  Something;
  try

	try
	  try
		raise Exception.Create('Exception #1');
	  finally
		Something;
	  end;
	except
	  raise;
    end;

	Something;
  except
	on e: Exception do begin
	  Writeln(e.Message, ': Exception "', e.ClassName, '"');
	  Writeln(e.StackTrace);

	  try
		Something;

		try
		  Something;

		  try

			try
			  raise Exception.Create('Exception #2');
			except
			  // test situation when AcquireExceptionObject is used:
			  AcquiredException := System.AcquireExceptionObject;
			end;

			Something;
			// reraise the catched exception:
			raise AcquiredException;

		  finally
			Something;
		  end;

		  Something;
		except
		  raise;
		end;

		Something;
	  except
		on e: Exception do begin
		  Writeln(e.Message, ': Exception "', e.ClassName, '"');
		  Writeln(e.StackTrace);
		end;
	  end;

	end;
  end;
  Something;
end;


 //===================================================================================================================
 // Testing native Windows exception "div by zero".
 //===================================================================================================================
procedure TestOsException;

  function _GetZero: integer;
  begin
	Result := 0;
  end;

var
  AcquiredException: TObject;
begin
  Something;
  try

	try
	  try
		Writeln(1 div _GetZero);	// force exception
	  finally
		Something;
	  end;
	except
	  raise;
    end;

	Something;
  except
	on e: Exception do begin
	  Writeln(e.Message, ': Exception "', e.ClassName, '"');
	  Writeln(e.StackTrace);

	  try
		Something;

		try
		  Something;

		  try
			// compiler cannot know that the division always throws an exception:
			AcquiredException := nil;

			try
			  Writeln(1 div _GetZero);	// force exception
			except
			  // test situation when AcquireExceptionObject is used:
			  AcquiredException := System.AcquireExceptionObject;
			end;

			Something;
			// reraise the catched exception:
			raise AcquiredException;

		  finally
			Something;
		  end;

		  Something;
		except
		  raise;
		end;

		Something;
	  except
		on e: Exception do begin
		  Writeln(e.Message, ': Exception "', e.ClassName, '"');
		  Writeln(e.StackTrace);
		end;
	  end;

	end;
  end;
  Something;
end;


 //===================================================================================================================
 // Testing native Windows exception "access violation".
 //===================================================================================================================
procedure TestEAccessViolation;
var
  AcquiredException: TObject;
begin
  Something;
  try

	try
	  try
		PByte(nil)[20] := 0;	// force exception
	  finally
		Something;
	  end;
	except
	  raise;
    end;

	Something;
  except
	on e: Exception do begin
	  Writeln(e.Message, ': Exception "', e.ClassName, '"');
	  Writeln(e.StackTrace);

	  try
		Something;

		try
		  Something;

		  try
			// compiler does not detect that the assignment always throws an exception:
			AcquiredException := nil;

			try
			  PByte(nil)[20] := 0;	// force exception
			except
			  // test situation when AcquireExceptionObject is used:
			  AcquiredException := System.AcquireExceptionObject;
			end;

			Something;
			// reraise the catched exception:
			raise AcquiredException;

		  finally
			Something;
		  end;

		  Something;
		except
		  raise;
		end;

		Something;
	  except
		on e: Exception do begin
		  Writeln(e.Message, ': Exception "', e.ClassName, '"');
		  Writeln(e.StackTrace);
		end;
	  end;

	end;
  end;
  Something;
end;


type
  // original COM interface:
  ITestComErr = interface(IUnknown)
	function ThrowError(arg: uint32; out res: uint32): HRESULT; stdcall;
  end;

  // minimal Delphi class which implements ITestComErr:
  TTestComErrObj = class(TInterfacedObject, ITestComErr)
  private
	function ThrowError(arg: uint32; out res: uint32): HRESULT; stdcall;
  end;

  // equivalent interface used as wrapper, using safecall:
  ITestComErrSafeCall = interface(IUnknown)
	function ThrowError(arg: uint32): uint32; safecall;
  end;


 //===================================================================================================================
 //===================================================================================================================
function TTestComErrObj.ThrowError(arg: uint32; out res: uint32): HRESULT;
begin
  res := arg;
  Result := E_NOTIMPL; //NOERROR
end;


 //===================================================================================================================
 // Testing exception thrown by safecall-wrapped COM method
 //===================================================================================================================
procedure TestSafecallException;
var
  ComObj: ITestComErrSafeCall;
  AcquiredException: TObject;
begin
  ITestComErr(ComObj) := TTestComErrObj.Create;

  Something;
  try

	try
	  try
		ComObj.ThrowError(42);
	  finally
		Something;
	  end;
	except
	  raise;
	end;

	Something;
  except
	on e: Exception do begin
	  Writeln(e.Message, ': Exception "', e.ClassName, '"');
	  Writeln(e.StackTrace);

	  try
		Something;

		try
		  Something;

		  try
			// Compiler cannot know that ThrowError always throws an exception:
			AcquiredException := nil;

			try
			  ComObj.ThrowError(42);
			except
			  // test situation when AcquireExceptionObject is used:
			  AcquiredException := System.AcquireExceptionObject;
			end;

			Something;
			// reraise the catched exception:
			raise AcquiredException;

		  finally
			Something;
		  end;

		  Something;
		except
		  raise;
		end;

		Something;
	  except
		on e: Exception do begin
		  Writeln(e.Message, ': Exception "', e.ClassName, '"');
		  Writeln(e.StackTrace);
		end;
	  end;

	end;
  end;
  Something;
end;


 //===================================================================================================================
 // Testing exception thrown by casting a COM interface to some non-supported interface:
 // In 32bit, the Delphi RTL puts a zero value as code address in the exception (System._IntfCast => System.Error => System.ErrorAt)!
 //   -> Due to this, you get no stacktrace at all for this exception.
 // In 64bit, is works as expected.
 //===================================================================================================================
procedure TestIntfCastException;
var
  Intf: IUnknown;
  Intf2: IDispatch;
begin
  // retrieve IDList:
  Intf := TTestComErrObj.Create;

  try
	// Try to cast to IDispatch which does QueryInterface and then raises an exception from within System._IntfCast:
	// This behaves differently than calling System.Error(reIntfCastError) directly: Due to the stack manipulation in
	// _IntfCast before the JMP to System.Error, MOV EDX,[ESP] in System.Error() does not read the return address from
	// the stack.
	Intf2 := Intf as IDispatch;
    //System.Error(reIntfCastError);
  except
	on e: Exception do begin
	  Writeln(e.Message, ': Exception "', e.ClassName, '"');
	  Writeln(e.StackTrace);
	end;
  end;
end;


 //===================================================================================================================
 // Testing symbols with non-ascii characters. The PDB format supports UTF8, so it should reproduce the correct names.
 // For the fully correct names in the stacktrace, an updated version of map2pdb.exe is required.
 //===================================================================================================================
procedure TestUnicodeSymbolNames;

	procedure UnicodeTest€ÄöÜß;

	  // same name as outer procedure (different casing!), needs to be handled correctly by map2pdb and the debug engine:
	  procedure UnicodeTest€äöüß;
	  begin
		raise Exceptionµ.Create('UnicodeTest');
	  end;

	  procedure UnicodeTest³€Äöüß²;
	  begin
		UnicodeTest€äöüß;
	  end;

	begin
	  UnicodeTest³€Äöüß²;
	end;

begin
  try
	UnicodeTest€äöüß;
  except
	on e: Exception do begin
	  // NOTE: The mapping of console output to the OEM character set is implemented somewhere after Delphi XE and before Delphi 10.
	  // To see the correct output with older Delphi versions,
	  // (a) you must redirect the output to a file,
	  // (b) open this textfile on a computer where the codepage is 1252.
	  // In cmd.exe:
	  //    SimpleTest.exe >output.txt
	  //    chcp 1252
	  //    notepad.exe output.txt
	  Writeln(e.Message, ': Exception "', e.ClassName, '"');
	  Writeln(e.StackTrace);
	end;
  end;
end;


 //===================================================================================================================
 //===================================================================================================================
function EnumWindowsCallback(hwnd: HWND; lParam: LPARAM): BOOL; stdcall;
begin
  Writeln('Callstack from inside EnumWindows:');
  Writeln(TStackTraceHlp.GetStackTrace);
  Result := false;
end;


 //===================================================================================================================
 // Testing stack trace with full Windows DLL symbols, by capturing a call stack inside a Windows callback.
 //===================================================================================================================
procedure TestCallStackFromWithinWindowsCallback;
begin
  Windows.EnumWindows(@EnumWindowsCallback, 0);
end;


 //===================================================================================================================
 // Verifying DLL unload detection in Stacktrace.pas: Load and unload a DLL *not* currently loaded by the process.
 //===================================================================================================================
procedure LoadAndUnloadSomeDLL;
var
  hMod: HMODULE;
begin
  hMod := Windows.LoadLibrary('hid.dll');
  Assert(hMod <> 0);
  Windows.FreeLibrary(hMod);
end;


 //===================================================================================================================
 // Run the tests.
 //===================================================================================================================
procedure Main;
begin
  //TStackTraceHlp.SymSearchPath := 'srv*c:\temp\symbols*https://msdl.microsoft.com/download/symbols';
  //TStackTraceHlp.EnableDebugOutput := true;

  SetLang;

  Writeln('Stacktrace without exception:');
  Writeln(TStackTraceHlp.GetStackTrace);

  Writeln('~~~~~~~~~~~~');
  
  TestUnicodeSymbolNames;

  Writeln('~~~~~~~~~~~~');

  TestDelpiException;

  Writeln('~~~~~~~~~~~~');

  LoadAndUnloadSomeDLL;

  TestOsException;

  Writeln('~~~~~~~~~~~~');

  LoadAndUnloadSomeDLL;

  TestEAccessViolation;

  Writeln('~~~~~~~~~~~~');

  TestSafecallException;

  Writeln('~~~~~~~~~~~~');

  TestIntfCastException;

  Writeln('~~~~~~~~~~~~');

  TestCallStackFromWithinWindowsCallback;

  Write('Finished (press ENTER).');
  Readln;
end;


begin
  Main;
end.
