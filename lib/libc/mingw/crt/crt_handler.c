/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include <windows.h>
#include <excpt.h>
#include <string.h>
#include <stdlib.h>
#include <malloc.h>
#include <memory.h>
#include <signal.h>
#include <stdio.h>

#if defined (_WIN64) && defined (__ia64__)
#error FIXME: Unsupported __ImageBase implementation.
#else
#ifndef _MSC_VER
#define __ImageBase __MINGW_LSYMBOL(_image_base__)
#endif
/* This symbol is defined by the linker.  */
extern IMAGE_DOS_HEADER __ImageBase;
#endif

#pragma pack(push,1)
typedef struct _UNWIND_INFO {
  BYTE VersionAndFlags;
  BYTE PrologSize;
  BYTE CountOfUnwindCodes;
  BYTE FrameRegisterAndOffset;
  ULONG AddressOfExceptionHandler;
} UNWIND_INFO,*PUNWIND_INFO;
#pragma pack(pop)

PIMAGE_SECTION_HEADER _FindPESectionByName (const char *);
PIMAGE_SECTION_HEADER _FindPESectionExec (size_t);
PBYTE _GetPEImageBase (void);

int __mingw_init_ehandler (void);
extern void _fpreset (void);

#if defined(__x86_64__) && !defined(_MSC_VER) && !defined(__SEH__)
EXCEPTION_DISPOSITION __mingw_SEH_error_handler(struct _EXCEPTION_RECORD *, void *, struct _CONTEXT *, void *);

#define MAX_PDATA_ENTRIES 32
static RUNTIME_FUNCTION emu_pdata[MAX_PDATA_ENTRIES];
static UNWIND_INFO emu_xdata[MAX_PDATA_ENTRIES];

int
__mingw_init_ehandler (void)
{
  static int was_here = 0;
  size_t e = 0;
  PIMAGE_SECTION_HEADER pSec;
  PBYTE _ImageBase = _GetPEImageBase ();
  
  if (was_here || !_ImageBase)
    return was_here;
  was_here = 1;
  if (_FindPESectionByName (".pdata") != NULL)
    return 1;

  /* Allocate # of e tables and entries.  */
  memset (emu_pdata, 0, sizeof (RUNTIME_FUNCTION) * MAX_PDATA_ENTRIES);
  memset (emu_xdata, 0, sizeof (UNWIND_INFO) * MAX_PDATA_ENTRIES);
    
  e = 0;
  /* Fill tables and entries.  */
  while (e < MAX_PDATA_ENTRIES && (pSec = _FindPESectionExec (e)) != NULL)
    {
      emu_xdata[e].VersionAndFlags = 9; /* UNW_FLAG_EHANDLER | UNW_VERSION */
      emu_xdata[e].AddressOfExceptionHandler =
	(DWORD)(size_t) ((LPBYTE)__mingw_SEH_error_handler - _ImageBase);
      emu_pdata[e].BeginAddress = pSec->VirtualAddress;
      emu_pdata[e].EndAddress = pSec->VirtualAddress + pSec->Misc.VirtualSize;
      emu_pdata[e].UnwindData =
	(DWORD)(size_t)((LPBYTE)&emu_xdata[e] - _ImageBase);
      ++e;
    }
#ifdef _DEBUG_CRT
  if (!e || e > MAX_PDATA_ENTRIES)
    abort ();
#endif
  /* RtlAddFunctionTable.  */
  if (e != 0)
    RtlAddFunctionTable (emu_pdata, e, (DWORD64)_ImageBase);
  return 1;
}

extern void _fpreset (void);

EXCEPTION_DISPOSITION
__mingw_SEH_error_handler (struct _EXCEPTION_RECORD* ExceptionRecord,
			   void *EstablisherFrame  __attribute__ ((unused)),
			   struct _CONTEXT* ContextRecord __attribute__ ((unused)),
			   void *DispatcherContext __attribute__ ((unused)))
{
  EXCEPTION_DISPOSITION action = ExceptionContinueSearch; /* EXCEPTION_CONTINUE_SEARCH; */
  void (*old_handler) (int);
  int reset_fpu = 0;

  switch (ExceptionRecord->ExceptionCode)
    {
    case EXCEPTION_ACCESS_VIOLATION:
      /* test if the user has set SIGSEGV */
      old_handler = signal (SIGSEGV, SIG_DFL);
      if (old_handler == SIG_IGN)
	{
	  /* this is undefined if the signal was raised by anything other
	     than raise ().  */
	  signal (SIGSEGV, SIG_IGN);
	  action = 0; //EXCEPTION_CONTINUE_EXECUTION;
	}
      else if (old_handler != SIG_DFL)
	{
	  /* This means 'old' is a user defined function. Call it */
	  (*old_handler) (SIGSEGV);
	  action = 0; // EXCEPTION_CONTINUE_EXECUTION;
	}
      else
        action = 4; /* EXCEPTION_EXECUTE_HANDLER; */
      break;
    case EXCEPTION_ILLEGAL_INSTRUCTION:
    case EXCEPTION_PRIV_INSTRUCTION:
      /* test if the user has set SIGILL */
      old_handler = signal (SIGILL, SIG_DFL);
      if (old_handler == SIG_IGN)
	{
	  /* this is undefined if the signal was raised by anything other
	     than raise ().  */
	  signal (SIGILL, SIG_IGN);
	  action = 0; // EXCEPTION_CONTINUE_EXECUTION;
	}
      else if (old_handler != SIG_DFL)
	{
	  /* This means 'old' is a user defined function. Call it */
	  (*old_handler) (SIGILL);
	  action = 0; // EXCEPTION_CONTINUE_EXECUTION;
	}
      else
        action = 4; /* EXCEPTION_EXECUTE_HANDLER;*/
      break;
    case EXCEPTION_FLT_INVALID_OPERATION:
    case EXCEPTION_FLT_DIVIDE_BY_ZERO:
    case EXCEPTION_FLT_DENORMAL_OPERAND:
    case EXCEPTION_FLT_OVERFLOW:
    case EXCEPTION_FLT_UNDERFLOW:
    case EXCEPTION_FLT_INEXACT_RESULT:
      reset_fpu = 1;
      /* fall through. */

    case EXCEPTION_INT_DIVIDE_BY_ZERO:
      /* test if the user has set SIGFPE */
      old_handler = signal (SIGFPE, SIG_DFL);
      if (old_handler == SIG_IGN)
	{
	  signal (SIGFPE, SIG_IGN);
	  if (reset_fpu)
	    _fpreset ();
	  action = 0; // EXCEPTION_CONTINUE_EXECUTION;
	}
      else if (old_handler != SIG_DFL)
	{
	  /* This means 'old' is a user defined function. Call it */
	  (*old_handler) (SIGFPE);
	  action = 0; // EXCEPTION_CONTINUE_EXECUTION;
	}
      break;
    case EXCEPTION_DATATYPE_MISALIGNMENT:
    case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:
    case EXCEPTION_FLT_STACK_CHECK:
    case EXCEPTION_INT_OVERFLOW:
    case EXCEPTION_INVALID_HANDLE:
    /*case EXCEPTION_POSSIBLE_DEADLOCK: */
      action = 0; // EXCEPTION_CONTINUE_EXECUTION;
      break;
    default:
      break;
    }
  return action;
}

#endif

LPTOP_LEVEL_EXCEPTION_FILTER __mingw_oldexcpt_handler = NULL;

long CALLBACK
_gnu_exception_handler (EXCEPTION_POINTERS *exception_data);

#define GCC_MAGIC (('G' << 16) | ('C' << 8) | 'C' | (1U << 29))

long CALLBACK
_gnu_exception_handler (EXCEPTION_POINTERS *exception_data)
{
  void (*old_handler) (int);
  long action = EXCEPTION_CONTINUE_SEARCH;
  int reset_fpu = 0;

#ifdef __SEH__
  if ((exception_data->ExceptionRecord->ExceptionCode & 0x20ffffff) == GCC_MAGIC)
    {
      if ((exception_data->ExceptionRecord->ExceptionFlags & EXCEPTION_NONCONTINUABLE) == 0)
        return EXCEPTION_CONTINUE_EXECUTION;
    }
#endif

  switch (exception_data->ExceptionRecord->ExceptionCode)
    {
    case EXCEPTION_ACCESS_VIOLATION:
      /* test if the user has set SIGSEGV */
      old_handler = signal (SIGSEGV, SIG_DFL);
      if (old_handler == SIG_IGN)
	{
	  /* this is undefined if the signal was raised by anything other
	     than raise ().  */
	  signal (SIGSEGV, SIG_IGN);
	  action = EXCEPTION_CONTINUE_EXECUTION;
	}
      else if (old_handler != SIG_DFL)
	{
	  /* This means 'old' is a user defined function. Call it */
	  (*old_handler) (SIGSEGV);
	  action = EXCEPTION_CONTINUE_EXECUTION;
	}
      break;

    case EXCEPTION_ILLEGAL_INSTRUCTION:
    case EXCEPTION_PRIV_INSTRUCTION:
      /* test if the user has set SIGILL */
      old_handler = signal (SIGILL, SIG_DFL);
      if (old_handler == SIG_IGN)
	{
	  /* this is undefined if the signal was raised by anything other
	     than raise ().  */
	  signal (SIGILL, SIG_IGN);
	  action = EXCEPTION_CONTINUE_EXECUTION;
	}
      else if (old_handler != SIG_DFL)
	{
	  /* This means 'old' is a user defined function. Call it */
	  (*old_handler) (SIGILL);
	  action = EXCEPTION_CONTINUE_EXECUTION;
	}
      break;

    case EXCEPTION_FLT_INVALID_OPERATION:
    case EXCEPTION_FLT_DIVIDE_BY_ZERO:
    case EXCEPTION_FLT_DENORMAL_OPERAND:
    case EXCEPTION_FLT_OVERFLOW:
    case EXCEPTION_FLT_UNDERFLOW:
    case EXCEPTION_FLT_INEXACT_RESULT:
      reset_fpu = 1;
      /* fall through. */

    case EXCEPTION_INT_DIVIDE_BY_ZERO:
      /* test if the user has set SIGFPE */
      old_handler = signal (SIGFPE, SIG_DFL);
      if (old_handler == SIG_IGN)
	{
	  signal (SIGFPE, SIG_IGN);
	  if (reset_fpu)
	    _fpreset ();
	  action = EXCEPTION_CONTINUE_EXECUTION;
	}
      else if (old_handler != SIG_DFL)
	{
	  /* This means 'old' is a user defined function. Call it */
	  (*old_handler) (SIGFPE);
	  action = EXCEPTION_CONTINUE_EXECUTION;
	}
      break;
#ifdef _WIN64
    case EXCEPTION_DATATYPE_MISALIGNMENT:
    case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:
    case EXCEPTION_FLT_STACK_CHECK:
    case EXCEPTION_INT_OVERFLOW:
    case EXCEPTION_INVALID_HANDLE:
    /*case EXCEPTION_POSSIBLE_DEADLOCK: */
      action = EXCEPTION_CONTINUE_EXECUTION;
      break;
#endif
    default:
      break;
    }

  if (action == EXCEPTION_CONTINUE_SEARCH && __mingw_oldexcpt_handler)
    action = (*__mingw_oldexcpt_handler)(exception_data);
  return action;
}
