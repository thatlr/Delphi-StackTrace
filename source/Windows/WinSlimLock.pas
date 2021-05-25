unit WinSlimLock;


{
  Unit only contains definitions that could also be used by MemTest.pas.
  - TSlimRWLock: Structure that wraps Windows' built-in Slim Reader/Writer Lock.
}


{$include LibOptions.inc}

{$ifdef MEMTEST_DEBUG}
  {$DebugInfo on}
{$else}
  {$DebugInfo off}
{$endif}

interface

uses Windows;

type
  TConditionVariable = Windows.CONDITION_VARIABLE;

  // Wraps Windows' built-in Slim Reader/Writer Lock (needs Windows Vista):
  // An initialization is not necessary if the corresponding variable is zero-initialized.
  TSlimRWLock = record
  strict private

	{WinNt.h + WinBase.h}
	type
	  SRWLOCK = type pointer;
	const
	  SRWLOCK_INIT = SRWLOCK(nil);

	class procedure _AcquireSRWLockExclusive(var SRWLock: SRWLOCK); stdcall; static;
	class procedure _AcquireSRWLockShared(var SRWLock: SRWLOCK); stdcall; static;
	class procedure _ReleaseSRWLockExclusive(var SRWLock: SRWLOCK); stdcall; static;
	class procedure _ReleaseSRWLockShared(var SRWLock: SRWLOCK); stdcall; static;
	class function _SleepConditionVariableSRW(var ConditionVariable: TConditionVariable; var SRWLock: SRWLOCK; dwMilliseconds: DWORD; Flags: ULONG): BOOL; stdcall; static;
	class function _TryAcquireSRWLockExclusive(var SRWLock: SRWLOCK): BOOL; stdcall; static;
	class function _TryAcquireSRWLockShared(var SRWLock: SRWLOCK): BOOL; stdcall; static;

	var
	  FLock: SRWLOCK;
  public
	procedure Init; inline;				// not needed if zero-initialized

	procedure AcquireExclusive; inline;
	function TryAcquireExclusive: boolean; inline;
	procedure ReleaseExclusive; inline;

	procedure AcquireShared; inline;
	function TryAcquireShared: boolean; inline;
	procedure ReleaseShared; inline;

	function SleepConditionVariable(var ConditionVariable: TConditionVariable; Milliseconds: DWORD; Flags: ULONG): boolean; inline;

	class procedure WakeAllConditionVariable(var ConditionVariable: TConditionVariable); stdcall; static;
	class procedure WakeConditionVariable(var ConditionVariable: TConditionVariable); stdcall; static;
  end;


{############################################################################}
implementation
{############################################################################}

{ TSlimRWLock }

class procedure TSlimRWLock._AcquireSRWLockExclusive(var SRWLock: SRWLOCK); stdcall; external Windows.kernel32 name 'AcquireSRWLockExclusive';
class procedure TSlimRWLock._AcquireSRWLockShared(var SRWLock: SRWLOCK); stdcall; external Windows.kernel32 name 'AcquireSRWLockShared';
class procedure TSlimRWLock._ReleaseSRWLockExclusive(var SRWLock: SRWLOCK); stdcall; external Windows.kernel32 name 'ReleaseSRWLockExclusive';
class procedure TSlimRWLock._ReleaseSRWLockShared(var SRWLock: SRWLOCK); stdcall; external Windows.kernel32 name 'ReleaseSRWLockShared';
class function TSlimRWLock._SleepConditionVariableSRW(var ConditionVariable: TConditionVariable; var SRWLock: SRWLOCK; dwMilliseconds: DWORD; Flags: ULONG): BOOL; stdcall; external Windows.kernel32 name 'SleepConditionVariableSRW';
class function TSlimRWLock._TryAcquireSRWLockExclusive(var SRWLock: SRWLOCK): BOOL; stdcall; external Windows.kernel32 name 'TryAcquireSRWLockExclusive';
class function TSlimRWLock._TryAcquireSRWLockShared(var SRWLock: SRWLOCK): BOOL; stdcall; external Windows.kernel32 name 'TryAcquireSRWLockShared';

// D2009: this functions are also in Windows.pas:
class procedure TSlimRWLock.WakeAllConditionVariable(var ConditionVariable: TConditionVariable); stdcall; external Windows.kernel32 name 'WakeAllConditionVariable';
class procedure TSlimRWLock.WakeConditionVariable(var ConditionVariable: TConditionVariable); stdcall; external Windows.kernel32 name 'WakeConditionVariable';


 //=============================================================================
 //=============================================================================
procedure TSlimRWLock.Init;
begin
  FLock := SRWLOCK_INIT;
end;

 //=============================================================================
 // Acquires the lock in exclusive mode:
 //=============================================================================
procedure TSlimRWLock.AcquireExclusive;
begin
  _AcquireSRWLockExclusive(FLock);
end;

 //=============================================================================
 // Acquires the lock in shared mode:
 //=============================================================================
procedure TSlimRWLock.AcquireShared;
begin
  _AcquireSRWLockShared(FLock);
end;

 //=============================================================================
 // Attempts to acquire the lock in exclusive mode. If the lock could be acquired,
 // it returns true.
 //=============================================================================
function TSlimRWLock.TryAcquireExclusive: boolean;
begin
  Result := _TryAcquireSRWLockExclusive(FLock);
end;

 //=============================================================================
 // Attempts to acquire the lock in shared mode. If the lock could be acquired,
 // it returns true.
 //=============================================================================
function TSlimRWLock.TryAcquireShared: boolean;
begin
  Result := _TryAcquireSRWLockShared(FLock);
end;

 //=============================================================================
 // Releases an lock that was opened in exclusive mode.
 //=============================================================================
procedure TSlimRWLock.ReleaseExclusive;
begin
  _ReleaseSRWLockExclusive(FLock);
end;

 //=============================================================================
 // Releases an SRW lock that was opened in shared mode.
 //=============================================================================
procedure TSlimRWLock.ReleaseShared;
begin
  _ReleaseSRWLockShared(FLock);
end;

 //=============================================================================
 // Sleeps on the condition variable and releases the specified lock as an atomic operation.
 //=============================================================================
function TSlimRWLock.SleepConditionVariable(var ConditionVariable: TConditionVariable; Milliseconds: DWORD; Flags: ULONG): boolean;
begin
  Result := _SleepConditionVariableSRW(ConditionVariable, FLock, Milliseconds, Flags);
end;

end.