/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_INTERNAL
#define _INC_INTERNAL

#include <crtdefs.h>

#ifdef __cplusplus
extern "C" {
#endif

#include <limits.h>
#include <fenv.h>
#include <windows.h>

#pragma pack(push,_CRT_PACKING)

#define __IOINFO_TM_ANSI 0
#define __IOINFO_TM_UTF8 1
#define __IOINFO_TM_UTF16LE 2

#ifdef _MSC_VER
#pragma warning(push)
#pragma warning(disable:4214)
#pragma warning(disable:4820)
#endif

  typedef struct {
    intptr_t osfhnd;
    char osfile;
    char pipech;
    int lockinitflag;
    CRITICAL_SECTION lock;
    char textmode : 7;
    char unicode : 1;
    char pipech2[2];
  } ioinfo;

#ifdef _MSC_VER
#pragma warning(pop)
#endif

#define IOINFO_ARRAY_ELTS (1 << 5)

#define _pioinfo(i) (__pioinfo[(i) >> 5] + ((i) & (IOINFO_ARRAY_ELTS - 1)))
#define _osfile(i) (_pioinfo(i)->osfile)
#define _pipech2(i) (_pioinfo(i)->pipech2)
#define _textmode(i) (_pioinfo(i)->textmode)
#define _tm_unicode(i) (_pioinfo(i)->unicode)
#define _pioinfo_safe(i) ((((i) != -1) && ((i) != -2)) ? _pioinfo(i) : &__badioinfo)
#define _osfhnd_safe(i) (_pioinfo_safe(i)->osfhnd)
#define _osfile_safe(i) (_pioinfo_safe(i)->osfile)
#define _pipech_safe(i) (_pioinfo_safe(i)->pipech)
#define _pipech2_safe(i) (_pioinfo_safe(i)->pipech2)
#define _textmode_safe(i) (_pioinfo_safe(i)->textmode)
#define _tm_unicode_safe(i) (_pioinfo_safe(i)->unicode)

#ifndef __badioinfo
  extern ioinfo * __MINGW_IMP_SYMBOL(__badioinfo);
#define __badioinfo (* __MINGW_IMP_SYMBOL(__badioinfo))
#endif

#ifndef __pioinfo
  extern ioinfo ** __MINGW_IMP_SYMBOL(__pioinfo)[];
#define __pioinfo (* __MINGW_IMP_SYMBOL(__pioinfo))
#endif

#define _NO_CONSOLE_FILENO (intptr_t)-2

#ifndef _FILE_DEFINED
#define _FILE_DEFINED
  struct _iobuf {
    char *_ptr;
    int _cnt;
    char *_base;
    int _flag;
    int _file;
    int _charbuf;
    int _bufsiz;
    char *_tmpfname;
  };
  typedef struct _iobuf FILE;
#endif

#if !defined (_FILEX_DEFINED) && defined (_WINDOWS_)
#define _FILEX_DEFINED
  typedef struct {
    FILE f;
    CRITICAL_SECTION lock;
  } _FILEX;
#endif

  extern int _dowildcard;
  extern int _newmode;

  _CRTIMP wchar_t *** __cdecl __p___winitenv(void);
#define __winitenv (*__p___winitenv())

  _CRTIMP char *** __cdecl __p___initenv(void);
#define __initenv (*__p___initenv())

  _CRTIMP void __cdecl _amsg_exit(int) __MINGW_ATTRIB_NORETURN;

  int __CRTDECL _setargv(void);
  int __CRTDECL __setargv(void);
  int __CRTDECL _wsetargv(void);
  int __CRTDECL __wsetargv(void);

  int __CRTDECL main(int _Argc, char **_Argv, char **_Env);
  int __CRTDECL wmain(int _Argc, wchar_t **_Argv, wchar_t **_Env);

#ifndef _STARTUP_INFO_DEFINED
#define _STARTUP_INFO_DEFINED
  typedef struct {
    int newmode;
  } _startupinfo;
#endif

  _CRTIMP int __cdecl __getmainargs(int * _Argc, char *** _Argv, char ***_Env, int _DoWildCard, _startupinfo *_StartInfo);
  _CRTIMP int __cdecl __wgetmainargs(int * _Argc, wchar_t ***_Argv, wchar_t ***_Env, int _DoWildCard, _startupinfo *_StartInfo);

#define _CONSOLE_APP 1
#define _GUI_APP 2

  typedef enum __enative_startup_state {
    __uninitialized = 0, __initializing, __initialized
  } __enative_startup_state;

  extern volatile __enative_startup_state __native_startup_state;
  extern void *volatile __native_startup_lock;

  extern volatile unsigned int __native_dllmain_reason;
  extern volatile unsigned int __native_vcclrit_reason;

  _CRTIMP void __cdecl __set_app_type (int);

  typedef LONG NTSTATUS;

#include <crtdbg.h>
#include <errno.h>

  BOOL __cdecl _ValidateImageBase (PBYTE pImageBase);
  PIMAGE_SECTION_HEADER __cdecl _FindPESection (PBYTE pImageBase, DWORD_PTR rva);
  BOOL __cdecl _IsNonwritableInCurrentImage (PBYTE pTarget);

#if defined(__SSE__)
# define __mingw_has_sse()  1
#elif defined(__i386__)
  int __mingw_has_sse(void);
#else
# define __mingw_has_sse()  0
#endif

#if defined(__i386__) || defined(__x86_64__)
enum fenv_masks
{
    /* x87 encoding constants */
    FENV_X_INVALID = 0x00100010,
    FENV_X_DENORMAL = 0x00200020,
    FENV_X_ZERODIVIDE = 0x00080008,
    FENV_X_OVERFLOW = 0x00040004,
    FENV_X_UNDERFLOW = 0x00020002,
    FENV_X_INEXACT = 0x00010001,
    FENV_X_AFFINE = 0x00004000,
    FENV_X_UP = 0x00800200,
    FENV_X_DOWN = 0x00400100,
    FENV_X_24 = 0x00002000,
    FENV_X_53 = 0x00001000,
    /* SSE encoding constants: they share the same lower word as their x87 counterparts
     * but differ in the upper word */
    FENV_Y_INVALID = 0x10000010,
    FENV_Y_DENORMAL = 0x20000020,
    FENV_Y_ZERODIVIDE = 0x08000008,
    FENV_Y_OVERFLOW = 0x04000004,
    FENV_Y_UNDERFLOW = 0x02000002,
    FENV_Y_INEXACT = 0x01000001,
    FENV_Y_UP = 0x80000200,
    FENV_Y_DOWN = 0x40000100,
    FENV_Y_FLUSH = 0x00000400,
    FENV_Y_FLUSH_SAVE = 0x00000800
};

/* encodes the x87 (represented as x) or SSE (represented as y) control/status word in a ulong */
static inline unsigned long fenv_encode(unsigned int x, unsigned int y)
{
    unsigned long ret = 0;

    if (x & _EM_INVALID) ret |= FENV_X_INVALID;
    if (x & _EM_DENORMAL) ret |= FENV_X_DENORMAL;
    if (x & _EM_ZERODIVIDE) ret |= FENV_X_ZERODIVIDE;
    if (x & _EM_OVERFLOW) ret |= FENV_X_OVERFLOW;
    if (x & _EM_UNDERFLOW) ret |= FENV_X_UNDERFLOW;
    if (x & _EM_INEXACT) ret |= FENV_X_INEXACT;
    if (x & _IC_AFFINE) ret |= FENV_X_AFFINE;
    if (x & _RC_UP) ret |= FENV_X_UP;
    if (x & _RC_DOWN) ret |= FENV_X_DOWN;
    if (x & _PC_24) ret |= FENV_X_24;
    if (x & _PC_53) ret |= FENV_X_53;

    if (y & _EM_INVALID) ret |= FENV_Y_INVALID;
    if (y & _EM_DENORMAL) ret |= FENV_Y_DENORMAL;
    if (y & _EM_ZERODIVIDE) ret |= FENV_Y_ZERODIVIDE;
    if (y & _EM_OVERFLOW) ret |= FENV_Y_OVERFLOW;
    if (y & _EM_UNDERFLOW) ret |= FENV_Y_UNDERFLOW;
    if (y & _EM_INEXACT) ret |= FENV_Y_INEXACT;
    if (y & _RC_UP) ret |= FENV_Y_UP;
    if (y & _RC_DOWN) ret |= FENV_Y_DOWN;
    if (y & _DN_FLUSH) ret |= FENV_Y_FLUSH;
    if (y & _DN_FLUSH_OPERANDS_SAVE_RESULTS) ret |= FENV_Y_FLUSH_SAVE;

    return ret;
}

/* decodes the x87 (represented as x) or SSE (represented as y) control/status word in a ulong */
static inline BOOL fenv_decode(unsigned long enc, unsigned int *x, unsigned int *y)
{
    *x = *y = 0;
    if ((enc & FENV_X_INVALID) == FENV_X_INVALID) *x |= _EM_INVALID;
    if ((enc & FENV_X_DENORMAL) == FENV_X_DENORMAL) *x |= _EM_DENORMAL;
    if ((enc & FENV_X_ZERODIVIDE) == FENV_X_ZERODIVIDE) *x |= _EM_ZERODIVIDE;
    if ((enc & FENV_X_OVERFLOW) == FENV_X_OVERFLOW) *x |= _EM_OVERFLOW;
    if ((enc & FENV_X_UNDERFLOW) == FENV_X_UNDERFLOW) *x |= _EM_UNDERFLOW;
    if ((enc & FENV_X_INEXACT) == FENV_X_INEXACT) *x |= _EM_INEXACT;
    if ((enc & FENV_X_AFFINE) == FENV_X_AFFINE) *x |= _IC_AFFINE;
    if ((enc & FENV_X_UP) == FENV_X_UP) *x |= _RC_UP;
    if ((enc & FENV_X_DOWN) == FENV_X_DOWN) *x |= _RC_DOWN;
    if ((enc & FENV_X_24) == FENV_X_24) *x |= _PC_24;
    if ((enc & FENV_X_53) == FENV_X_53) *x |= _PC_53;

    if ((enc & FENV_Y_INVALID) == FENV_Y_INVALID) *y |= _EM_INVALID;
    if ((enc & FENV_Y_DENORMAL) == FENV_Y_DENORMAL) *y |= _EM_DENORMAL;
    if ((enc & FENV_Y_ZERODIVIDE) == FENV_Y_ZERODIVIDE) *y |= _EM_ZERODIVIDE;
    if ((enc & FENV_Y_OVERFLOW) == FENV_Y_OVERFLOW) *y |= _EM_OVERFLOW;
    if ((enc & FENV_Y_UNDERFLOW) == FENV_Y_UNDERFLOW) *y |= _EM_UNDERFLOW;
    if ((enc & FENV_Y_INEXACT) == FENV_Y_INEXACT) *y |= _EM_INEXACT;
    if ((enc & FENV_Y_UP) == FENV_Y_UP) *y |= _RC_UP;
    if ((enc & FENV_Y_DOWN) == FENV_Y_DOWN) *y |= _RC_DOWN;
    if ((enc & FENV_Y_FLUSH) == FENV_Y_FLUSH) *y |= _DN_FLUSH;
    if ((enc & FENV_Y_FLUSH_SAVE) == FENV_Y_FLUSH_SAVE) *y |= _DN_FLUSH_OPERANDS_SAVE_RESULTS;

    return fenv_encode(*x, *y) == enc;
}
#else
static inline unsigned long fenv_encode(unsigned int x, unsigned int y)
{
    /* Encode _EM_DENORMAL as 0x20 for Windows compatibility. */
    if (y & _EM_DENORMAL)
        y = (y & ~_EM_DENORMAL) | 0x20;

    return x | y;
}

static inline BOOL fenv_decode(unsigned long enc, unsigned int *x, unsigned int *y)
{
    /* Decode 0x20 as _EM_DENORMAL. */
    if (enc & 0x20)
        enc = (enc & ~0x20) | _EM_DENORMAL;

    *x = *y = enc;
    return TRUE;
}
#endif

void __mingw_setfp( unsigned int *cw, unsigned int cw_mask, unsigned int *sw, unsigned int sw_mask );
void __mingw_setfp_sse( unsigned int *cw, unsigned int cw_mask, unsigned int *sw, unsigned int sw_mask );
unsigned int __mingw_controlfp(unsigned int newval, unsigned int mask);
#if defined(__i386__) || (defined(__x86_64__) && !defined(__arm64ec__))
int __mingw_control87_2(unsigned int, unsigned int, unsigned int *, unsigned int *);
#endif

static inline unsigned int __mingw_statusfp(void)
{
    unsigned int flags = 0;
#if defined(__i386__) || (defined(__x86_64__) && !defined(__arm64ec__))
    unsigned int x86_sw, sse2_sw = 0;
    __mingw_setfp(NULL, 0, &x86_sw, 0);
    if (__mingw_has_sse())
        __mingw_setfp_sse(NULL, 0, &sse2_sw, 0);
    flags = x86_sw | sse2_sw;
#else
    __mingw_setfp(NULL, 0, &flags, 0);
#endif
    return flags;
}

/* Use naked functions only on Clang. GCC doesn’t support them on ARM targets and
 * has broken behavior on x86_64 by emitting .seh_endprologue. */
#ifndef __clang__

#define __ASM_DEFINE_FUNC(rettype, name, args, code) \
    asm(".text\n\t" \
        ".p2align 2\n\t" \
        ".globl " __MINGW64_STRINGIFY(__MINGW_USYMBOL(name)) "\n\t" \
        ".def " __MINGW64_STRINGIFY(__MINGW_USYMBOL(name)) "; .scl 2; .type 32; .endef\n\t" \
        __MINGW64_STRINGIFY(__MINGW_USYMBOL(name)) ":\n\t" \
        code "\n\t");

#else

#define __ASM_DEFINE_FUNC(rettype, name, args, code) \
    rettype __attribute__((naked)) name args { \
        asm(code "\n\t"); \
    }

#endif

#ifdef __cplusplus
}
#endif

#pragma pack(pop)
#endif
