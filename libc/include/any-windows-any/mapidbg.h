/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __MAPIDBG_H_
#define __MAPIDBG_H_

#define IFDBG(x)
#define IFNDBG(x) x

#ifdef __cplusplus
#define EXTERN_C_BEGIN extern "C" {
#define EXTERN_C_END }
#else
#define EXTERN_C_BEGIN
#define EXTERN_C_END
#endif

#define dimensionof(a) (sizeof(a)/sizeof(*(a)))

#define Unreferenced(a) ((void)(a))

#ifndef BASETYPES
#define BASETYPES
  typedef unsigned __LONG32 ULONG;
  typedef ULONG *PULONG;
  typedef unsigned short USHORT;
  typedef USHORT *PUSHORT;
  typedef unsigned char UCHAR;
  typedef UCHAR *PUCHAR;
  typedef char *PSZ;
#endif

typedef __LONG32 SCODE;
typedef unsigned __LONG32 DWORD;

#ifdef ASSERTS_ENABLED
#define IFTRAP(x) x
#else
#define IFTRAP(x) 0
#endif

#define Trap() IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,"Trap"))
#define TrapSz(psz) IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz))
#define TrapSz1(psz,a1) IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1))
#define TrapSz2(psz,a1,a2) IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2))
#define TrapSz3(psz,a1,a2,a3) IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3))
#define TrapSz4(psz,a1,a2,a3,a4) IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4))
#define TrapSz5(psz,a1,a2,a3,a4,a5) IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5))
#define TrapSz6(psz,a1,a2,a3,a4,a5,a6) IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6))
#define TrapSz7(psz,a1,a2,a3,a4,a5,a6,a7) IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7))
#define TrapSz8(psz,a1,a2,a3,a4,a5,a6,a7,a8) IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7,a8))
#define TrapSz9(psz,a1,a2,a3,a4,a5,a6,a7,a8,a9) IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7,a8,a9))

#define Assert(t) IFTRAP(((t) ? 0 : DebugTrapFn(1,__FILE__,__LINE__,"Assertion Failure: " #t),0))
#define AssertSz(t,psz) IFTRAP(((t) ? 0 : DebugTrapFn(1,__FILE__,__LINE__,psz),0))
#define AssertSz1(t,psz,a1) IFTRAP(((t) ? 0 : DebugTrapFn(1,__FILE__,__LINE__,psz,a1),0))
#define AssertSz2(t,psz,a1,a2) IFTRAP(((t) ? 0 : DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2),0))
#define AssertSz3(t,psz,a1,a2,a3) IFTRAP(((t) ? 0 : DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3),0))
#define AssertSz4(t,psz,a1,a2,a3,a4) IFTRAP(((t) ? 0 : DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4),0))
#define AssertSz5(t,psz,a1,a2,a3,a4,a5) IFTRAP(((t) ? 0 : DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5),0))
#define AssertSz6(t,psz,a1,a2,a3,a4,a5,a6) IFTRAP(((t) ? 0 : DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6),0))
#define AssertSz7(t,psz,a1,a2,a3,a4,a5,a6,a7) IFTRAP(((t) ? 0 : DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7),0))
#define AssertSz8(t,psz,a1,a2,a3,a4,a5,a6,a7,a8) IFTRAP(((t) ? 0 : DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7,a8),0))
#define AssertSz9(t,psz,a1,a2,a3,a4,a5,a6,a7,a8,a9) IFTRAP(((t) ? 0 : DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7,a8,a9),0))

#define SideAssert(t) ((t) ? 0 : IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,"Assertion Failure: " #t)),0)
#define SideAssertSz(t,psz) ((t) ? 0 : IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz)),0)
#define SideAssertSz1(t,psz,a1) ((t) ? 0 : IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1)),0)
#define SideAssertSz2(t,psz,a1,a2) ((t) ? 0 : IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2)),0)
#define SideAssertSz3(t,psz,a1,a2,a3) ((t) ? 0 : IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3)),0)
#define SideAssertSz4(t,psz,a1,a2,a3,a4) ((t) ? 0 : IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4)),0)
#define SideAssertSz5(t,psz,a1,a2,a3,a4,a5) ((t) ? 0 : IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5)),0)
#define SideAssertSz6(t,psz,a1,a2,a3,a4,a5,a6) ((t) ? 0 : IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6)),0)
#define SideAssertSz7(t,psz,a1,a2,a3,a4,a5,a6,a7) ((t) ? 0 : IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7)),0)
#define SideAssertSz8(t,psz,a1,a2,a3,a4,a5,a6,a7,a8) ((t) ? 0 : IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7,a8)),0)
#define SideAssertSz9(t,psz,a1,a2,a3,a4,a5,a6,a7,a8,a9) ((t) ? 0 : IFTRAP(DebugTrapFn(1,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7,a8,a9)),0)

#define NFAssert(t) IFTRAP(((t) ? 0 : DebugTrapFn(0,__FILE__,__LINE__,"Assertion Failure: " #t),0))
#define NFAssertSz(t,psz) IFTRAP(((t) ? 0 : DebugTrapFn(0,__FILE__,__LINE__,psz),0))
#define NFAssertSz1(t,psz,a1) IFTRAP(((t) ? 0 : DebugTrapFn(0,__FILE__,__LINE__,psz,a1),0))
#define NFAssertSz2(t,psz,a1,a2) IFTRAP(((t) ? 0 : DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2),0))
#define NFAssertSz3(t,psz,a1,a2,a3) IFTRAP(((t) ? 0 : DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3),0))
#define NFAssertSz4(t,psz,a1,a2,a3,a4) IFTRAP(((t) ? 0 : DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4),0))
#define NFAssertSz5(t,psz,a1,a2,a3,a4,a5) IFTRAP(((t) ? 0 : DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5),0))
#define NFAssertSz6(t,psz,a1,a2,a3,a4,a5,a6) IFTRAP(((t) ? 0 : DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6),0))
#define NFAssertSz7(t,psz,a1,a2,a3,a4,a5,a6,a7) IFTRAP(((t) ? 0 : DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7),0))
#define NFAssertSz8(t,psz,a1,a2,a3,a4,a5,a6,a7,a8) IFTRAP(((t) ? 0 : DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7,a8),0))
#define NFAssertSz9(t,psz,a1,a2,a3,a4,a5,a6,a7,a8,a9) IFTRAP(((t) ? 0 : DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7,a8,a9),0))

#define NFSideAssert(t) ((t) ? 0 : IFTRAP(DebugTrapFn(0,__FILE__,__LINE__,"Assertion Failure: " #t)),0)
#define NFSideAssertSz(t,psz) ((t) ? 0 : IFTRAP(DebugTrapFn(0,__FILE__,__LINE__,psz)),0)
#define NFSideAssertSz1(t,psz,a1) ((t) ? 0 : IFTRAP(DebugTrapFn(0,__FILE__,__LINE__,psz,a1)),0)
#define NFSideAssertSz2(t,psz,a1,a2) ((t) ? 0 : IFTRAP(DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2)),0)
#define NFSideAssertSz3(t,psz,a1,a2,a3) ((t) ? 0 : IFTRAP(DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3)),0)
#define NFSideAssertSz4(t,psz,a1,a2,a3,a4) ((t) ? 0 : IFTRAP(DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4)),0)
#define NFSideAssertSz5(t,psz,a1,a2,a3,a4,a5) ((t) ? 0 : IFTRAP(DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5)),0)
#define NFSideAssertSz6(t,psz,a1,a2,a3,a4,a5,a6) ((t) ? 0 : IFTRAP(DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6)),0)
#define NFSideAssertSz7(t,psz,a1,a2,a3,a4,a5,a6,a7) ((t) ? 0 : IFTRAP(DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7)),0)
#define NFSideAssertSz8(t,psz,a1,a2,a3,a4,a5,a6,a7,a8) ((t) ? 0 : IFTRAP(DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7,a8)),0)
#define NFSideAssertSz9(t,psz,a1,a2,a3,a4,a5,a6,a7,a8,a9) ((t) ? 0 : IFTRAP(DebugTrapFn(0,__FILE__,__LINE__,psz,a1,a2,a3,a4,a5,a6,a7,a8,a9)),0)

#ifdef TRACES_ENABLED
#define IFTRACE(x) x
#define DebugTrace DebugTraceFn
#else
#define IFTRACE(x) 0
#define DebugTrace 1?0:DebugTraceFn
#endif

#define DebugTraceResult(f,hr) IFTRACE(((hr) ? DebugTraceFn(#f " returns 0x%08lX %s\n",GetScode(hr),(0)) : 0))
#define DebugTraceSc(f,sc) IFTRACE(((sc) ? DebugTraceFn(#f " returns 0x%08lX %s\n",sc,(0)) : 0))
#define DebugTraceArg(f,s) IFTRACE(DebugTraceFn(#f ": bad parameter: " s "\n"))
#define DebugTraceLine() IFTRACE(DebugTraceFn("File %s, Line %i	\n",__FILE__,__LINE__))
#define DebugTraceProblems(sz,rgprob) IFTRACE(DebugTraceProblemsFn(sz,rgprob))

#define TraceSz(psz) IFTRACE(DebugTraceFn("~" psz))
#define TraceSz1(psz,a1) IFTRACE(DebugTraceFn("~" psz,a1))
#define TraceSz2(psz,a1,a2) IFTRACE(DebugTraceFn("~" psz,a1,a2))
#define TraceSz3(psz,a1,a2,a3) IFTRACE(DebugTraceFn("~" psz,a1,a2,a3))
#define TraceSz4(psz,a1,a2,a3,a4) IFTRACE(DebugTraceFn("~" psz,a1,a2,a3,a4))
#define TraceSz5(psz,a1,a2,a3,a4,a5) IFTRACE(DebugTraceFn("~" psz,a1,a2,a3,a4,a5))
#define TraceSz6(psz,a1,a2,a3,a4,a5,a6) IFTRACE(DebugTraceFn("~" psz,a1,a2,a3,a4,a5,a6))
#define TraceSz7(psz,a1,a2,a3,a4,a5,a6,a7) IFTRACE(DebugTraceFn("~" psz,a1,a2,a3,a4,a5,a6,a7))
#define TraceSz8(psz,a1,a2,a3,a4,a5,a6,a7,a8) IFTRACE(DebugTraceFn("~" psz,a1,a2,a3,a4,a5,a6,a7,a8))
#define TraceSz9(psz,a1,a2,a3,a4,a5,a6,a7,a8,a9) IFTRACE(DebugTraceFn("~" psz,a1,a2,a3,a4,a5,a6,a7,a8,a9))

EXTERN_C_BEGIN

#define EXPORTDBG

int EXPORTDBG __cdecl DebugTrapFn(int fFatal,char *pszFile,int iLine,char *pszFormat,...);
int EXPORTDBG __cdecl DebugTraceFn(char *pszFormat,...);
void EXPORTDBG __cdecl DebugTraceProblemsFn(char *sz,void *rgprob);
char *EXPORTDBG __cdecl SzDecodeScodeFn(SCODE sc);
char *EXPORTDBG __cdecl SzDecodeUlPropTypeFn(unsigned __LONG32 ulPropType);
char *EXPORTDBG __cdecl SzDecodeUlPropTagFn(unsigned __LONG32 ulPropTag);
unsigned __LONG32 EXPORTDBG __cdecl UlPropTagFromSzFn(char *psz);
SCODE EXPORTDBG __cdecl ScodeFromSzFn(char *psz);
void *EXPORTDBG __cdecl DBGMEM_EncapsulateFn(void *pmalloc,char *pszSubsys,int fCheckOften);
void EXPORTDBG __cdecl DBGMEM_ShutdownFn(void *pmalloc);
void EXPORTDBG __cdecl DBGMEM_CheckMemFn(void *pmalloc,int fReportOrphans);
#ifdef _X86_
void EXPORTDBG __cdecl DBGMEM_LeakHook(FARPROC pfn);
void EXPORTDBG __cdecl GetCallStack(DWORD *,int,int);
#endif
void EXPORTDBG __cdecl DBGMEM_NoLeakDetectFn(void *pmalloc,void *pv);
void EXPORTDBG __cdecl DBGMEM_SetFailureAtFn(void *pmalloc,ULONG ulFailureAt);
SCODE EXPORTDBG __cdecl ScCheckScFn(SCODE,SCODE *,char *,char *,int);
void *EXPORTDBG __cdecl VMAlloc(ULONG);
void *EXPORTDBG __cdecl VMAllocEx(ULONG,ULONG);
void *EXPORTDBG __cdecl VMRealloc(void *,ULONG);
void *EXPORTDBG __cdecl VMReallocEx(void *,ULONG,ULONG);
ULONG EXPORTDBG __cdecl VMGetSize(void *);
ULONG EXPORTDBG __cdecl VMGetSizeEx(void *,ULONG);
void EXPORTDBG __cdecl VMFree(void *);
void EXPORTDBG __cdecl VMFreeEx(void *,ULONG);

EXTERN_C_END

#define SzDecodeScode(_sc) (0)
#define SzDecodeUlPropType(_ulPropType) (0)
#define SzDecodeUlPropTag(_ulPropTag) (0)
#define UlPropTagFromSz(_sz) (0)
#define ScodeFromSz(_sz) (0)

#if defined(__cplusplus) && !defined(CINTERFACE)
#define DBGMEM_Encapsulate(pmalloc,pszSubsys,fCheckOften) ((pmalloc)->AddRef(),(pmalloc))
#define DBGMEM_Shutdown(pmalloc) ((pmalloc)->Release())
#else
#define DBGMEM_Encapsulate(pmalloc,pszSubsys,fCheckOften) ((pmalloc)->lpVtbl->AddRef(pmalloc),(pmalloc))
#define DBGMEM_Shutdown(pmalloc) ((pmalloc)->lpVtbl->Release(pmalloc))
#endif
#define DBGMEM_CheckMem(pm,f)
#define DBGMEM_NoLeakDetect(pm,pv)
#define DBGMEM_SetFailureAt(pm,ul)

#define ScCheckSc(sc,fn) (sc)
#define HrCheckHr(hr,fn) (hr)

#define HrCheckSc(sc,fn) ResultFromScode(ScCheckSc(sc,fn))

#endif
