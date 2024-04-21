/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_SETJMP
#define _INC_SETJMP

#include <crtdefs.h>

#pragma pack(push,_CRT_PACKING)

#ifndef NULL
#ifdef __cplusplus
#ifndef _WIN64
#define NULL 0
#else
#define NULL 0LL
#endif  /* W64 */
#else
#define NULL ((void *)0)
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

#if (defined(_X86_) && !defined(__x86_64))

#define _JBLEN 16
#define _JBTYPE int

  typedef struct __JUMP_BUFFER {
    unsigned long Ebp;
    unsigned long Ebx;
    unsigned long Edi;
    unsigned long Esi;
    unsigned long Esp;
    unsigned long Eip;
    unsigned long Registration;
    unsigned long TryLevel;
    unsigned long Cookie;
    unsigned long UnwindFunc;
    unsigned long UnwindData[6];
  } _JUMP_BUFFER;

#elif defined(__ia64__)

  typedef _CRT_ALIGN(16) struct _SETJMP_FLOAT128 {
    __MINGW_EXTENSION __int64 LowPart;
    __MINGW_EXTENSION __int64 HighPart;
  } SETJMP_FLOAT128;

#define _JBLEN 33
  typedef SETJMP_FLOAT128 _JBTYPE;

  typedef struct __JUMP_BUFFER {

    unsigned long iAReserved[6];

    unsigned long Registration;
    unsigned long TryLevel;
    unsigned long Cookie;
    unsigned long UnwindFunc;

    unsigned long UnwindData[6];

    SETJMP_FLOAT128 FltS0;
    SETJMP_FLOAT128 FltS1;
    SETJMP_FLOAT128 FltS2;
    SETJMP_FLOAT128 FltS3;
    SETJMP_FLOAT128 FltS4;
    SETJMP_FLOAT128 FltS5;
    SETJMP_FLOAT128 FltS6;
    SETJMP_FLOAT128 FltS7;
    SETJMP_FLOAT128 FltS8;
    SETJMP_FLOAT128 FltS9;
    SETJMP_FLOAT128 FltS10;
    SETJMP_FLOAT128 FltS11;
    SETJMP_FLOAT128 FltS12;
    SETJMP_FLOAT128 FltS13;
    SETJMP_FLOAT128 FltS14;
    SETJMP_FLOAT128 FltS15;
    SETJMP_FLOAT128 FltS16;
    SETJMP_FLOAT128 FltS17;
    SETJMP_FLOAT128 FltS18;
    SETJMP_FLOAT128 FltS19;
    __MINGW_EXTENSION __int64 FPSR;
    __MINGW_EXTENSION __int64 StIIP;
    __MINGW_EXTENSION __int64 BrS0;
    __MINGW_EXTENSION __int64 BrS1;
    __MINGW_EXTENSION __int64 BrS2;
    __MINGW_EXTENSION __int64 BrS3;
    __MINGW_EXTENSION __int64 BrS4;
    __MINGW_EXTENSION __int64 IntS0;
    __MINGW_EXTENSION __int64 IntS1;
    __MINGW_EXTENSION __int64 IntS2;
    __MINGW_EXTENSION __int64 IntS3;
    __MINGW_EXTENSION __int64 RsBSP;
    __MINGW_EXTENSION __int64 RsPFS;
    __MINGW_EXTENSION __int64 ApUNAT;
    __MINGW_EXTENSION __int64 ApLC;
    __MINGW_EXTENSION __int64 IntSp;
    __MINGW_EXTENSION __int64 IntNats;
    __MINGW_EXTENSION __int64 Preds;

  } _JUMP_BUFFER;

#elif defined(__x86_64)

  typedef _CRT_ALIGN(16) struct _SETJMP_FLOAT128 {
    __MINGW_EXTENSION unsigned __int64 Part[2];
  } SETJMP_FLOAT128;

#define _JBLEN 16
  typedef SETJMP_FLOAT128 _JBTYPE;

  typedef struct _JUMP_BUFFER {
    __MINGW_EXTENSION unsigned __int64 Frame;
    __MINGW_EXTENSION unsigned __int64 Rbx;
    __MINGW_EXTENSION unsigned __int64 Rsp;
    __MINGW_EXTENSION unsigned __int64 Rbp;
    __MINGW_EXTENSION unsigned __int64 Rsi;
    __MINGW_EXTENSION unsigned __int64 Rdi;
    __MINGW_EXTENSION unsigned __int64 R12;
    __MINGW_EXTENSION unsigned __int64 R13;
    __MINGW_EXTENSION unsigned __int64 R14;
    __MINGW_EXTENSION unsigned __int64 R15;
    __MINGW_EXTENSION unsigned __int64 Rip;
    unsigned long MxCsr;
    unsigned short FpCsr;
    unsigned short Spare;
    SETJMP_FLOAT128 Xmm6;
    SETJMP_FLOAT128 Xmm7;
    SETJMP_FLOAT128 Xmm8;
    SETJMP_FLOAT128 Xmm9;
    SETJMP_FLOAT128 Xmm10;
    SETJMP_FLOAT128 Xmm11;
    SETJMP_FLOAT128 Xmm12;
    SETJMP_FLOAT128 Xmm13;
    SETJMP_FLOAT128 Xmm14;
    SETJMP_FLOAT128 Xmm15;
  } _JUMP_BUFFER;

#elif defined(_ARM_)

#define _JBLEN 28
#define _JBTYPE int

  typedef struct __JUMP_BUFFER {
    unsigned long Frame;
    unsigned long R4;
    unsigned long R5;
    unsigned long R6;
    unsigned long R7;
    unsigned long R8;
    unsigned long R9;
    unsigned long R10;
    unsigned long R11;
    unsigned long Sp;
    unsigned long Pc;
    unsigned long Fpscr;
    unsigned long long D[8];
  } _JUMP_BUFFER;

#elif defined(_ARM64_)

#define _JBLEN 24
#define _JBTYPE unsigned __int64

  typedef struct __JUMP_BUFFER {
    unsigned __int64 Frame;
    unsigned __int64 Reserved;
    unsigned __int64 X19;
    unsigned __int64 X20;
    unsigned __int64 X21;
    unsigned __int64 X22;
    unsigned __int64 X23;
    unsigned __int64 X24;
    unsigned __int64 X25;
    unsigned __int64 X26;
    unsigned __int64 X27;
    unsigned __int64 X28;
    unsigned __int64 Fp;
    unsigned __int64 Lr;
    unsigned __int64 Sp;
    unsigned long Fpcr;
    unsigned long Fpsr;
    double D[8];
  } _JUMP_BUFFER;

#else

#define _JBLEN 1
#define _JBTYPE int

#endif

#ifndef _JMP_BUF_DEFINED
  typedef _JBTYPE jmp_buf[_JBLEN];
#define _JMP_BUF_DEFINED
#endif

_CRTIMP __MINGW_ATTRIB_NORETURN __attribute__ ((__nothrow__)) void __cdecl longjmp(jmp_buf _Buf,int _Value);

void * __cdecl __attribute__ ((__nothrow__)) mingw_getsp (void);

#pragma push_macro("__has_builtin")
#ifndef __has_builtin
  #define __has_builtin(x) 0
#endif

#ifdef _UCRT
#  ifdef _WIN64
#    define _setjmp __intrinsic_setjmpex
#  else
#    define _setjmp __intrinsic_setjmp
#  endif
#elif defined(__aarch64__)
     /* ARM64 msvcrt.dll lacks _setjmp, only has _setjmpex. */
#  define _setjmp _setjmpex
#endif
#ifndef _INC_SETJMPEX
#  if defined(_X86_) || defined(__i386__)
#    define setjmp(BUF) _setjmp3((BUF), NULL)
#  elif ((defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__)) && (!defined(__SEH__) || !__has_builtin(__builtin_sponentry) || defined(__USE_MINGW_SETJMP_NON_SEH)))
#    define setjmp(BUF) __mingw_setjmp((BUF))
#    define longjmp __mingw_longjmp
  int __cdecl __attribute__ ((__nothrow__,__returns_twice__)) __mingw_setjmp(jmp_buf _Buf);
  __MINGW_ATTRIB_NORETURN __attribute__ ((__nothrow__)) void __mingw_longjmp(jmp_buf _Buf,int _Value);
#  elif defined(__SEH__) && !defined(__USE_MINGW_SETJMP_NON_SEH)
#    if defined(__aarch64__) || defined(_ARM64_) || defined(__arm__) || defined(_ARM_)
#      define setjmp(BUF) _setjmp((BUF), __builtin_sponentry())
#    elif (__MINGW_GCC_VERSION < 40702) && !defined(__clang__)
#      define setjmp(BUF) _setjmp((BUF), mingw_getsp())
#    else
#      define setjmp(BUF) _setjmp((BUF), __builtin_frame_address (0))
#    endif
#  else
#    define setjmp(BUF) _setjmp((BUF), NULL)
#  endif
  int __cdecl __attribute__ ((__nothrow__,__returns_twice__)) _setjmp(jmp_buf _Buf, void *_Ctx);
  int __cdecl __attribute__ ((__nothrow__,__returns_twice__)) _setjmp3(jmp_buf _Buf, void *_Ctx);
#else
#  undef setjmp
#  ifdef __SEH__
#    if (__MINGW_GCC_VERSION < 40702) && !defined(__clang__)
#      define setjmp(BUF) _setjmpex((BUF), mingw_getsp())
#      define setjmpex(BUF) _setjmpex((BUF), mingw_getsp())
#    else
#      define setjmp(BUF) _setjmpex((BUF), __builtin_frame_address (0))
#      define setjmpex(BUF) _setjmpex((BUF), __builtin_frame_address (0))
#    endif
#  else
#    define setjmp(BUF) _setjmpex((BUF), NULL)
#    define setjmpex(BUF) _setjmpex((BUF), NULL)
#  endif
  int __cdecl __attribute__ ((__nothrow__,__returns_twice__)) _setjmpex(jmp_buf _Buf,void *_Ctx);
#endif

#pragma pop_macro("__has_builtin")

#ifdef __cplusplus
}
#endif

#pragma pack(pop)
#endif
