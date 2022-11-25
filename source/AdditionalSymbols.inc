//
// see: http://docwiki.embarcadero.com/RADStudio/en/Compiler_Versions
//
// https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Compiler_Versions

{$undef Delphi2}
{$undef Delphi3}
{$undef Delphi4}
{$undef Delphi5}
{$undef Delphi6}
{$undef Delphi7}
{$undef Delphi8}
{$undef D2005}
{$undef D2006}
{$undef D2007}
{$undef D2009}
{$undef D2010}
{$undef D2011}
{$undef DelphiXE}
{$undef DelphiXE2}
{$undef DelphiXE3}
{$undef DelphiXE4}
{$undef DelphiXE5}
{$undef DelphiXE6}
{$undef DelphiXE7}
{$undef DelphiXE8}
{$undef Delphi10}
{$undef Delphi101}
{$undef Delphi102}
{$undef Delphi103}
{$undef Delphi104}
{$undef Delphi11}

// D2: VER90
// D3: VER100
// D4: VER120
// D5: VER130
// D6: VER140
// D7: VER150
// D8: VER160
// D2005: VER170
// D2006: VER180
// D2007: VER190

// D2009:
{$ifdef VER200}
  {$define Delphi2
  {$define Delphi3
  {$define Delphi4
  {$define Delphi5
  {$define Delphi6
  {$define Delphi7
  {$define Delphi8
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
{$endif}

// D2010:
{$ifdef VER210}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
{$endif}

// D2011/XE:
{$ifdef VER220}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
{$endif}

// XE2:
{$ifdef VER230}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
{$endif}

// XE3:
{$ifdef VER240}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
{$endif}

// XE4:
{$ifdef VER250}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
  {$define DelphiXE4}
{$endif}

// XE5:
{$ifdef VER260}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
  {$define DelphiXE4}
  {$define DelphiXE5}
{$endif}

// XE6:
{$ifdef VER270}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
  {$define DelphiXE4}
  {$define DelphiXE5}
  {$define DelphiXE6}
{$endif}

// XE7:
{$ifdef VER280}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
  {$define DelphiXE4}
  {$define DelphiXE5}
  {$define DelphiXE6}
  {$define DelphiXE7}
{$endif}

// XE8:
{$ifdef VER290}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
  {$define DelphiXE4}
  {$define DelphiXE5}
  {$define DelphiXE6}
  {$define DelphiXE7}
  {$define DelphiXE8}
{$endif}

// D10 Seattle:
{$ifdef VER300}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
  {$define DelphiXE4}
  {$define DelphiXE5}
  {$define DelphiXE6}
  {$define DelphiXE7}
  {$define DelphiXE8}
  {$define Delphi10}
{$endif}

// D10.1 Berlin:
{$ifdef VER310}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
  {$define DelphiXE4}
  {$define DelphiXE5}
  {$define DelphiXE6}
  {$define DelphiXE7}
  {$define DelphiXE8}
  {$define Delphi10}
  {$define Delphi101}
{$endif}

// D10.2 Tokyo:
{$ifdef VER320}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
  {$define DelphiXE4}
  {$define DelphiXE5}
  {$define DelphiXE6}
  {$define DelphiXE7}
  {$define DelphiXE8}
  {$define Delphi10}
  {$define Delphi101}
  {$define Delphi102}
{$endif}

// D10.3 Rio:
{$ifdef VER330}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
  {$define DelphiXE4}
  {$define DelphiXE5}
  {$define DelphiXE6}
  {$define DelphiXE7}
  {$define DelphiXE8}
  {$define Delphi10}
  {$define Delphi101}
  {$define Delphi102}
  {$define Delphi103}
{$endif}

// D10.4 Sydney:
{$ifdef VER340}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
  {$define DelphiXE4}
  {$define DelphiXE5}
  {$define DelphiXE6}
  {$define DelphiXE7}
  {$define DelphiXE8}
  {$define Delphi10}
  {$define Delphi101}
  {$define Delphi102}
  {$define Delphi103}
  {$define Delphi104}
{$endif}

// D11.0 Alexandria
{$ifdef VER350}
  {$define Delphi2}
  {$define Delphi3}
  {$define Delphi4}
  {$define Delphi5}
  {$define Delphi6}
  {$define Delphi7}
  {$define Delphi8}
  {$define D2005}
  {$define D2006}
  {$define D2007}
  {$define D2009}
  {$define D2010}
  {$define D2011}
  {$define DelphiXE}
  {$define DelphiXE2}
  {$define DelphiXE3}
  {$define DelphiXE4}
  {$define DelphiXE5}
  {$define DelphiXE6}
  {$define DelphiXE7}
  {$define DelphiXE8}
  {$define Delphi10}
  {$define Delphi101}
  {$define Delphi102}
  {$define Delphi103}
  {$define Delphi104}
  {$define Delphi11}
{$endif}

