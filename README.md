# Delphi-StackTrace
Capturing call stacks in Delphi

This provides support for capturing and displaying
stack traces at exceptions or at any custom points
in Delphi code.

Because it is based on Windows StackWalk functionality,
it works for any module (exe and dll), as long as a matching PDB 
file is providing the mapping between code addresses
and funtion names plus source code location.

Therefore, you can use Anders Melander's map2pdb from https://github.com/andersmelander/map2pdb
and enjoy nice complete and correct stack traces.

Tested with:
- Delphi 2009
- Delphi XE
- Delphi 10.1.2 Berlin: 32bit and 64bit
- Delphi 12.1 Athens: 32bit and 64bit

To use it:
- Include the Stacktrace unit, by manually adding it to the top of the uses list in the dpr file.
- Compile all source files with {$StackFrames on}. It is not strictly required but gives better stacktraces.
- In the Delphi Project options, under "Linking", set "Map File" to "Detailed".
- Under "Build Events", "Post-Build", add this command:
		map2pdb.exe  "-include:0001;0002"  "$(OUTPUTDIR)\$(OUTPUTNAME).map"

  You may want to use map2pdb with additional filters, as the PDBs gets very large, especially on 64bit.
- Ship the PDB files together with the EXEs and DLLs, by putting them in the same directory.


Usage notes:

- The EAbort exception does not generate a stack trace because I think it is intended to implement control flow
(i.e. abort processing without a special message). The VCL swallows EAbort exceptions in several places:
TApplication.HandleException(), TCustomApplicationEvents.DoException(), TMultiCaster.DoException().

- The CPU stack does not record *where the call came from* but stores *where to continue after the call*. This leads to an effect
that can also be experienced in the Delphi debugger: Sometimes, the source line in the stack trace is the line with the next
statement that follows the actual call.

- The Delphi runtime units (RTL, VCL, etc) are precompiled with {$StackFrames off} ({$W-}). Sometimes this leads to missing frames in
the stack trace, since the debug engine has to guess how to interpret the stack. Since map2pdb only has the Delphi MAP file as
input, the PDB file will most likely not contain "Frame Pointer Omission (FPO)" records, which would help the debug engine in
these cases (https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/symbols-and-symbol-files).

- In SysUtils, there are two singleton exception objects stored in the private global variables "OutOfMemory" and "InvalidPointer".
Those are thrown by the procedure "System.Error" when called with reOutOfMemory or reInvalidPtr, respectively. Unfortunately, this
is done by System.GetMem, System.AllocMem, System.FreeMem and System.ReallocMem to signal errors.
As this singletons are *not thread-safe* in regards of (a) attaching stacktrace info to them, and (b) modifying the message text
(Exception.Message) by application code, this approach should have been discarded with the explicit introduction of multi-threading
in Delphi (TThread class, later: Parallel Programming Library).

  While I understand that out-of-memory is a situation where a pre-allocated exception object is useful (but it has to be thread-specific,
or read-only, otherwise it won't work reliably in multi-threading scenarios), I don't understand why FreeMem() and ReallocMem() don't
just throw an exception when erroneous application behavior is detected (e.g. an attempt to double-free memory). If the heap structure
is already corrupt, throwing an exception doesn't help the application, even if a preallocated object is used. But if the heap structure
is not corrupt, it would be useful to have a stack trace for a FreeMem() error. However, the EHeapException.RaisingException() method
suppresses stacktrace generation for this exception classes.
(Which at least prevents multiple threads from attaching their respective stack trace to it at the same time, thereby producing memory errors.
But the Message property is not readonly, and modifying it on a singleton from multiple threads at the same time will cause memory leaks.)

  Conclusion: A heap manager replacement should signal errors within FreeMem() and ReallocMem() by explicitly throwing a normal exception
not derived from EHeapException. A non-zero value must only be returned by FreeMem() and ReallocMem() when the heap management
structures are corrupted, but should not be returned if a duplicate free attempt or an invalid pointer is detected before the heap was
corrupted. As long as the heap is not full and not corrupted, a normal non-EHeapException will suffice.


Please note:

As the Delphi runtime library handles things not consistently and contains bugs (see some of the comments in the code),
I don't know if this works with other Delphi versions as well. Please use a memory leak detector to verify the behavior.

Generally, the 64bit compiler and RTL fixes a few things, as exception reraising now always reuses the original exception
object and it also generates source-line infos for the main part of the dpr file (the lines between "begin" and "end.").

The 32bit compiler and RTL makes it nearly impossible to get the stacktrace from an non-delphi exception that is reraised:
For some reason, the original exception object is released by the RTL and then a new one is created, but we still need the
stackinfo from the original object which is now gone. It is not possible to recreate it. So for now, I just reattach the
very last stackinfo, but depending on other exceptions thrown and catched between the original point and the reraise point,
it may be no longer the correct one. But: When AcquireExceptionObject is used, reraising works also in 32bit for every type
of exception.


## Enable lookup of Windows symbols

For general info, please look here:
  https://learn.microsoft.com/en-us/windows/win32/dxtecharts/debugging-with-symbols

The standard dbghelp.dll that comes with Windows does not support downloading from symbol servers. To use this, you need
two DLLs from the "Windows Debugging Tools":
  https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/debugger-download-tools

Both "dbghelp.dll" and "symsrv.dll" from
	  "C:\Program Files (x86)\Windows Kits\10\Debuggers\x86" (32 bit)
or
	  "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64" (64 bit)
needs to be copied into the same folder as the Delphi executable.

To have the Windows symbols be used, the symbol search path needs to be altered, like this:

	TStackTraceHlp.SymSearchPath := 'srv*c:\temp\symbols*https://msdl.microsoft.com/download/symbols';

"c:\temp\symbols" inside this example string specifies a folder that is used as a cache for the downloaded PDBs (see
  https://learn.microsoft.com/en-us/windows/win32/debug/symbol-paths).

As the download takes time and needs internet connectivity, and the cache folder needs to be placed somewhere, this is usually not an option
for production environments (at least not on end-user PCs).

Example stacktrace without Windows symbols (32 bit):
  
	Callstack from inside EnumWindows:
	  at SimpleTest.exe: EnumWindowsCallback in SimpleTest.dpr (Line 372)
	  at user32.dll: SendMessageW + 0x111
	  at user32.dll: EnumWindows + 0x1A
	  at SimpleTest.exe: TestCallStackFromWithinWindowsCallback in SimpleTest.dpr (Line 383)
	  at SimpleTest.exe: Main in SimpleTest.dpr (Line 436)
	  at SimpleTest.exe: SimpleTest + 0x1D
	  at KERNEL32.DLL: BaseThreadInitThunk + 0x19
	  at ntdll.dll: RtlGetAppContainerNamedObjectPath + 0x11E
	  at ntdll.dll: RtlGetAppContainerNamedObjectPath + 0xEE

Same with Windows symbols (32 bit):

	Callstack from inside EnumWindows:
	  at SimpleTest.exe: EnumWindowsCallback in SimpleTest.dpr (Line 372)
	  at user32.dll: EnumWindowsWorker + 0x88
	  at user32.dll: EnumWindows + 0x1A
	  at SimpleTest.exe: TestCallStackFromWithinWindowsCallback in SimpleTest.dpr (Line 383)
	  at SimpleTest.exe: Main in SimpleTest.dpr (Line 435)
	  at SimpleTest.exe: SimpleTest + 0x1D
	  at KERNEL32.DLL: BaseThreadInitThunk + 0x19
	  at ntdll.dll: __RtlUserThreadStart + 0x2F
	  at ntdll.dll: _RtlUserThreadStart + 0x1B
