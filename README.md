# Delphi-StackTrace
Capturing call stacks in Delphi

This provides support for capturing and displaying
stack traces at exceptions or at any custom points
in Delphi code.

Because it is based on Windows StackWalk functionality,
it works for any module (exe and dll), as long as a matching PDB 
file is providing the mapping between code addresses
and funtion names plus source code location.

Therefore, you can use Anders Melander's map2pdb from https://bitbucket.org/anders_melander/map2pdb
and enjoy nice complete and correct stack traces.

Tested with:
- Delphi 2009
- Delphi 10.1.2 Berlin: 32bit and 64bit

To use it:
- Include the Stacktrace unit, by manually adding it to the top of the uses list in the dpr file.
- Compile all source files with {$StackFrames on}. It is not strictly required but gives better stacktraces.
- In the Delphi Project options, under "Linking", set "Map File" to "Detailed".
- Under "Build Events", "Post-Build", add this command:
		map2pdb.exe  "-include:0001;0002"  "$(OUTPUTDIR)\$(OUTPUTNAME).map"

  You may want to use map2pdb with additional filters, as the PDBs gets very large, especially on 64bit.
- Ship the PDB files together with the EXEs and DLLs, by putting them in the same directory.

Please note:
As the Delphi runtime library handles things not consistently and contains bugs (see some of the comments in the code),
I don't know if this works with other Delphi versions as well. Please use a memory leak detector to verify the behavior.

Generally, the 64bit compiler and RTL fixes a few things, as exception reraising now always reuses the original exception
object and it also generates source-line infos for the main part of the dpr file (the lines between "begin" and "end.").

The 32bit compiler and RTL makes it nearly impossible to get the stacktrace from an non-delphi exception that is reraised:
For some reason, the original exception object is released by the RTL and then a new one is created, but we still need the
stackinfo from the original object which is now gone. It is not possible to recreate it. So for now, I just reattach the
very last stackinfo, but depending on other exceptions thrown and catched between the original point and the reraise point,
it may be no longer the correct one.


Open issue:

When a DLL get unloaded, it's address space may get reused by other DLls loaded thereafter. So the symbol cache maintained by
DbgHelp needs to be invalided somehow on DLL unloading. But there is no clean way to get notifications from Windows when a
DLL is unloaded (besides LdrRegisterDllNotification which is marked "deprecated" by Microsoft).
