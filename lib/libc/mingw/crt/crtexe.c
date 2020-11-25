/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#undef CRTDLL
#ifndef _DLL
#define _DLL
#endif

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#define SPECIAL_CRTEXE

#include <oscalls.h>
#include <internal.h>
#include <process.h>
#include <signal.h>
#include <math.h>
#include <stdlib.h>
#include <tchar.h>
#include <sect_attribs.h>
#include <locale.h>

#if defined(__SEH__) && (!defined(__clang__) || __clang_major__ >= 7)
#define SEH_INLINE_ASM
#endif

#ifndef __winitenv
extern wchar_t *** __MINGW_IMP_SYMBOL(__winitenv);
#define __winitenv (* __MINGW_IMP_SYMBOL(__winitenv))
#endif

#if !defined(__initenv) && !defined(__arm__) && !defined(__aarch64__)
extern char *** __MINGW_IMP_SYMBOL(__initenv);
#define __initenv (* __MINGW_IMP_SYMBOL(__initenv))
#endif

/* Hack, for bug in ld.  Will be removed soon.  */
#if defined(__GNUC__)
#define __ImageBase __MINGW_LSYMBOL(_image_base__)
#endif
/* This symbol is defined by ld.  */
extern IMAGE_DOS_HEADER __ImageBase;

extern void _fpreset (void);
#define SPACECHAR _T(' ')
#define DQUOTECHAR _T('\"')

int *__cdecl __p__commode(void);

#undef _fmode
extern int _fmode;
extern int _commode;
extern int _dowildcard;

extern _CRTIMP void __cdecl _initterm(_PVFV *, _PVFV *);

static int __cdecl check_managed_app (void);

extern _CRTALLOC(".CRT$XIA") _PIFV __xi_a[];
extern _CRTALLOC(".CRT$XIZ") _PIFV __xi_z[];
extern _CRTALLOC(".CRT$XCA") _PVFV __xc_a[];
extern _CRTALLOC(".CRT$XCZ") _PVFV __xc_z[];

#ifndef HAVE_CTOR_LIST
__attribute__ (( __section__ (".ctors"), __used__ , aligned(sizeof(void *)))) const void * __CTOR_LIST__ = (void *) -1;
__attribute__ (( __section__ (".dtors"), __used__ , aligned(sizeof(void *)))) const void * __DTOR_LIST__ = (void *) -1;
__attribute__ (( __section__ (".ctors.99999"), __used__ , aligned(sizeof(void *)))) const void * __CTOR_END__ = (void *) 0;
__attribute__ (( __section__ (".dtors.99999"), __used__ , aligned(sizeof(void *)))) const void * __DTOR_END__ = (void *) 0;
#endif

/* TLS initialization hook.  */
extern const PIMAGE_TLS_CALLBACK __dyn_tls_init_callback;

extern int mingw_app_type;

HINSTANCE __mingw_winmain_hInstance;
_TCHAR *__mingw_winmain_lpCmdLine;
DWORD __mingw_winmain_nShowCmd = SW_SHOWDEFAULT;

static int argc;
extern void __main(void);
#ifdef WPRFLAG
static wchar_t **argv;
static wchar_t **envp;
#else
static char **argv;
static char **envp;
#endif

static int argret;
static int mainret=0;
static int managedapp;
static int has_cctor = 0;
static _startupinfo startinfo;
extern LPTOP_LEVEL_EXCEPTION_FILTER __mingw_oldexcpt_handler;

extern void _pei386_runtime_relocator (void);
long CALLBACK _gnu_exception_handler (EXCEPTION_POINTERS * exception_data);
#ifdef WPRFLAG
static void duplicate_ppstrings (int ac, wchar_t ***av);
#else
static void duplicate_ppstrings (int ac, char ***av);
#endif

static int __cdecl pre_c_init (void);
static void __cdecl pre_cpp_init (void);
_CRTALLOC(".CRT$XIAA") _PIFV mingw_pcinit = pre_c_init;
_CRTALLOC(".CRT$XCAA") _PVFV mingw_pcppinit = pre_cpp_init;

extern int _MINGW_INSTALL_DEBUG_MATHERR;

#ifdef __MINGW_SHOW_INVALID_PARAMETER_EXCEPTION
#define __UNUSED_PARAM_1(x) x
#else
#define __UNUSED_PARAM_1	__UNUSED_PARAM
#endif
static void
__mingw_invalidParameterHandler (const wchar_t * __UNUSED_PARAM_1(expression),
				 const wchar_t * __UNUSED_PARAM_1(function),
				 const wchar_t * __UNUSED_PARAM_1(file),
				 unsigned int    __UNUSED_PARAM_1(line),
				 uintptr_t __UNUSED_PARAM(pReserved))
{
#ifdef __MINGW_SHOW_INVALID_PARAMETER_EXCEPTION
  wprintf(L"Invalid parameter detected in function %s. File: %s Line: %d\n", function, file, line);
  wprintf(L"Expression: %s\n", expression);
#endif
}

static int __cdecl
pre_c_init (void)
{
  managedapp = check_managed_app ();
  if (mingw_app_type)
    __set_app_type(_GUI_APP);
  else
    __set_app_type (_CONSOLE_APP);

  * __p__fmode() = _fmode;
  * __p__commode() = _commode;

#ifdef WPRFLAG
  _wsetargv();
#else
  _setargv();
#endif
  if (_MINGW_INSTALL_DEBUG_MATHERR == 1)
    {
      __setusermatherr (_matherr);
    }

  if (__globallocalestatus == -1)
    {
    }
  return 0;
}

static void __cdecl
pre_cpp_init (void)
{
  startinfo.newmode = _newmode;

#ifdef WPRFLAG
  argret = __wgetmainargs(&argc,&argv,&envp,_dowildcard,&startinfo);
#else
  argret = __getmainargs(&argc,&argv,&envp,_dowildcard,&startinfo);
#endif
}

static int __tmainCRTStartup (void);

int WinMainCRTStartup (void);

int WinMainCRTStartup (void)
{
  int ret = 255;
#ifdef SEH_INLINE_ASM
  asm ("\t.l_startw:\n");
#endif
  mingw_app_type = 1;
  ret = __tmainCRTStartup ();
#ifdef SEH_INLINE_ASM
  asm ("\tnop\n"
    "\t.l_endw: nop\n"
    "\t.seh_handler __C_specific_handler, @except\n"
    "\t.seh_handlerdata\n"
    "\t.long 1\n"
    "\t.rva .l_startw, .l_endw, _gnu_exception_handler ,.l_endw\n"
    "\t.text");
#endif
  return ret;
}

int mainCRTStartup (void);

#if defined(__x86_64__) && !defined(__SEH__)
int __mingw_init_ehandler (void);
#endif

int mainCRTStartup (void)
{
  int ret = 255;
#ifdef SEH_INLINE_ASM
  asm ("\t.l_start:\n");
#endif
  mingw_app_type = 0;
  ret = __tmainCRTStartup ();
#ifdef SEH_INLINE_ASM
  asm ("\tnop\n"
    "\t.l_end: nop\n"
    "\t.seh_handler __C_specific_handler, @except\n"
    "\t.seh_handlerdata\n"
    "\t.long 1\n"
    "\t.rva .l_start, .l_end, _gnu_exception_handler ,.l_end\n"
    "\t.text");
#endif
  return ret;
}

static
#if defined(__i386__) || defined(_X86_)
/* We need to make sure that we align the stack to 16 bytes for the sake of SSE
   opts in main or in functions called main.  */
__attribute__((force_align_arg_pointer))
#endif
__declspec(noinline) int
__tmainCRTStartup (void)
{
  _TCHAR *lpszCommandLine = NULL;
  STARTUPINFO StartupInfo;
  WINBOOL inDoubleQuote = FALSE;
  memset (&StartupInfo, 0, sizeof (STARTUPINFO));

  if (mingw_app_type)
    GetStartupInfo (&StartupInfo);
  {
    void *lock_free = NULL;
    void *fiberid = ((PNT_TIB)NtCurrentTeb())->StackBase;
    int nested = FALSE;
    while((lock_free = InterlockedCompareExchangePointer ((volatile PVOID *) &__native_startup_lock,
							  fiberid, 0)) != 0)
      {
	if (lock_free == fiberid)
	  {
	    nested = TRUE;
	    break;
	  }
	Sleep(1000);
      }
    if (__native_startup_state == __initializing)
      {
	_amsg_exit (31);
      }
    else if (__native_startup_state == __uninitialized)
      {
	__native_startup_state = __initializing;
	_initterm ((_PVFV *)(void *)__xi_a, (_PVFV *)(void *) __xi_z);
      }
    else
      has_cctor = 1;

    if (__native_startup_state == __initializing)
      {
	_initterm (__xc_a, __xc_z);
	__native_startup_state = __initialized;
      }
    _ASSERTE(__native_startup_state == __initialized);
    if (! nested)
      (VOID)InterlockedExchangePointer ((volatile PVOID *) &__native_startup_lock, 0);
    
    if (__dyn_tls_init_callback != NULL)
      __dyn_tls_init_callback (NULL, DLL_THREAD_ATTACH, NULL);
    
    _pei386_runtime_relocator ();
    __mingw_oldexcpt_handler = SetUnhandledExceptionFilter (_gnu_exception_handler);
#if defined(__x86_64__) && !defined(__SEH__)
    __mingw_init_ehandler ();
#endif
    _set_invalid_parameter_handler (__mingw_invalidParameterHandler);
    
    _fpreset ();

    __mingw_winmain_hInstance = (HINSTANCE) &__ImageBase;

#ifdef WPRFLAG
    lpszCommandLine = (_TCHAR *) _wcmdln;
#else
    lpszCommandLine = (char *) _acmdln;
#endif

    if (lpszCommandLine)
      {
	while (*lpszCommandLine > SPACECHAR || (*lpszCommandLine && inDoubleQuote))
	  {
	    if (*lpszCommandLine == DQUOTECHAR)
	      inDoubleQuote = !inDoubleQuote;
#ifdef _MBCS
	    if (_ismbblead (*lpszCommandLine))
	      {
		if (lpszCommandLine[1])
		  ++lpszCommandLine;
	      }
#endif
	    ++lpszCommandLine;
	  }
	while (*lpszCommandLine && (*lpszCommandLine <= SPACECHAR))
	  lpszCommandLine++;

	__mingw_winmain_lpCmdLine = lpszCommandLine;
      }

    if (mingw_app_type)
      {
	__mingw_winmain_nShowCmd = StartupInfo.dwFlags & STARTF_USESHOWWINDOW ?
				    StartupInfo.wShowWindow : SW_SHOWDEFAULT;
      }
    duplicate_ppstrings (argc, &argv);
    __main ();
#ifdef WPRFLAG
    __winitenv = envp;
    /* C++ initialization.
       gcc inserts this call automatically for a function called main, but not for wmain.  */
    mainret = wmain (argc, argv, envp);
#else
#if !defined(__arm__) && !defined(__aarch64__)
    __initenv = envp;
#endif
    mainret = main (argc, argv, envp);
#endif
    if (!managedapp)
      exit (mainret);

    if (has_cctor == 0)
      _cexit ();
  }
  return mainret;
}

extern int mingw_initltsdrot_force;
extern int mingw_initltsdyn_force;
extern int mingw_initltssuo_force;
extern int mingw_initcharmax;

static int __cdecl
check_managed_app (void)
{
  PIMAGE_DOS_HEADER pDOSHeader;
  PIMAGE_NT_HEADERS pPEHeader;
  PIMAGE_OPTIONAL_HEADER32 pNTHeader32;
  PIMAGE_OPTIONAL_HEADER64 pNTHeader64;

  /* Force to be linked.  */
  mingw_initltsdrot_force=1;
  mingw_initltsdyn_force=1;
  mingw_initltssuo_force=1;
  mingw_initcharmax=1;

  pDOSHeader = (PIMAGE_DOS_HEADER) &__ImageBase;
  if (pDOSHeader->e_magic != IMAGE_DOS_SIGNATURE)
    return 0;

  pPEHeader = (PIMAGE_NT_HEADERS)((char *)pDOSHeader + pDOSHeader->e_lfanew);
  if (pPEHeader->Signature != IMAGE_NT_SIGNATURE)
    return 0;

  pNTHeader32 = (PIMAGE_OPTIONAL_HEADER32) &pPEHeader->OptionalHeader;
  switch (pNTHeader32->Magic)
    {
    case IMAGE_NT_OPTIONAL_HDR32_MAGIC:
      if (pNTHeader32->NumberOfRvaAndSizes <= IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR)
	return 0;
      return !! pNTHeader32->DataDirectory[IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR].VirtualAddress;
    case IMAGE_NT_OPTIONAL_HDR64_MAGIC:
      pNTHeader64 = (PIMAGE_OPTIONAL_HEADER64)pNTHeader32;
      if (pNTHeader64->NumberOfRvaAndSizes <= IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR)
	return 0;
      return !! pNTHeader64->DataDirectory[IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR].VirtualAddress;
    }
  return 0;
}

#ifdef WPRFLAG
static size_t wbytelen(const wchar_t *p)
{
	size_t ret = 1;
	while (*p!=0) {
		ret++,++p;
	}
	return ret*2;
}
static void duplicate_ppstrings (int ac, wchar_t ***av)
{
	wchar_t **avl;
	int i;
	wchar_t **n = (wchar_t **) malloc (sizeof (wchar_t *) * (ac + 1));

	avl=*av;
	for (i=0; i < ac; i++)
	  {
		size_t l = wbytelen (avl[i]);
		n[i] = (wchar_t *) malloc (l);
		memcpy (n[i], avl[i], l);
	  }
	n[i] = NULL;
	*av = n;
}
#else
static void duplicate_ppstrings (int ac, char ***av)
{
	char **avl;
	int i;
	char **n = (char **) malloc (sizeof (char *) * (ac + 1));
	
	avl=*av;
	for (i=0; i < ac; i++)
	  {
		size_t l = strlen (avl[i]) + 1;
		n[i] = (char *) malloc (l);
		memcpy (n[i], avl[i], l);
	  }
	n[i] = NULL;
	*av = n;
}
#endif

int __cdecl atexit (_PVFV func)
{
    return _onexit((_onexit_t)func) ? 0 : -1;
}

char __mingw_module_is_dll = 0;
