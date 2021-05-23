# Delphi-StackTrace
Capturing call stacks in Delphi

This provides support for capturing and displaying
stack traces at exceptions or at any custom points
in Delphi code.

Because it is based on Windows StackWalk functionality,
it works for any module, as long as a matching PDB 
file is providing the mapping between code addresses
and funtion names plus source code location.

Therefore, you can use Anders Melanders' map2pdb,
and enjoy nice complete and correct stack traces.

Tested with:
- Delphi 2009
- Delphi 10.1.2 Berlin: 32bit and 64bit
