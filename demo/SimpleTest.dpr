program SimpleTest;

{$include CompilerOptions.inc}

uses
  Stacktrace,
  Windows,
  SysUtils;

// IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE = $8000: Terminal server aware
// IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE = $40: Address Space Layout Randomization (ASLR) enabled
// IMAGE_DLLCHARACTERISTICS_NX_COMPAT = $100: Data Execution Prevention (DEP) enabled
{$SetPeOptFlags $8140}

// IMAGE_FILE_LARGE_ADDRESS_AWARE: may use heap/code above 2GB
{$SetPeFlags IMAGE_FILE_LARGE_ADDRESS_AWARE}


 //===================================================================================================================
 // the compiler will generate code at the call site for this
 //===================================================================================================================
procedure Something;
begin
end;


 //===================================================================================================================
 //===================================================================================================================
function GetZero: integer;
begin
  Result := 0;
end;


 //===================================================================================================================
 //===================================================================================================================
procedure TestDelpiException;
begin
  Something;
  try
	Writeln('TestDelpiException #1:');
	Writeln(TStackTraceHlp.GetStackTrace);

	try
	  raise Exception.Create('Exception #1');
	finally
	  Something;
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
			raise Exception.Create('Exception #2');
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

	  Writeln('TestDelpiException #2:');
	  Writeln(TStackTraceHlp.GetStackTrace);
	end;
  end;
  Something;
end;


 //===================================================================================================================
 //===================================================================================================================
procedure TestOsException;
begin
  Something;
  try
	Writeln('TestOsException #1:');
	Writeln(TStackTraceHlp.GetStackTrace);

	try
	  Writeln(1 div GetZero);	// force exception
	finally
	  Something;
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
			Writeln(1 div GetZero);	// force exception
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

	  Writeln('TestOsException #2:');
	  Writeln(TStackTraceHlp.GetStackTrace);
	end;
  end;
  Something;
end;


 //===================================================================================================================
 //===================================================================================================================
procedure Test2;
begin
(*
  try
	try
	  //Writeln(1 div GetZero);	// force exception
	  Abort;
	except
	  raise;
	end;
  except
	on e: Exception do begin
	  Writeln(e.Message, ': Exception "', e.ClassName, '"');
	  Writeln(e.StackTrace);
	end;
  end;
  exit;
*)

  TestDelpiException;
  Writeln('~~~~~~~~~~~~');
  TestOsException;
end;


 //===================================================================================================================
 //===================================================================================================================
procedure Test1;
begin
  try
	Test2;
  finally
//	Test2;
  end;
end;


begin
  Test1;

  Readln;
end.

