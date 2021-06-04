/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <crtdefs.h>

#ifndef _INC_CRTDBG
#define _INC_CRTDBG

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

  typedef void *_HFILE;

#define _CRT_WARN 0
#define _CRT_ERROR 1
#define _CRT_ASSERT 2
#define _CRT_ERRCNT 3

#define _CRTDBG_MODE_FILE 0x1
#define _CRTDBG_MODE_DEBUG 0x2
#define _CRTDBG_MODE_WNDW 0x4
#define _CRTDBG_REPORT_MODE -1

#define _CRTDBG_INVALID_HFILE ((_HFILE)-1)
#define _CRTDBG_HFILE_ERROR ((_HFILE)-2)
#define _CRTDBG_FILE_STDOUT ((_HFILE)-4)
#define _CRTDBG_FILE_STDERR ((_HFILE)-5)
#define _CRTDBG_REPORT_FILE ((_HFILE)-6)

  typedef int (__cdecl *_CRT_REPORT_HOOK)(int,char *,int *);
  typedef int (__cdecl *_CRT_REPORT_HOOKW)(int,wchar_t *,int *);

#define _CRT_RPTHOOK_INSTALL 0
#define _CRT_RPTHOOK_REMOVE 1

#define _HOOK_ALLOC 1
#define _HOOK_REALLOC 2
#define _HOOK_FREE 3

  typedef int (__cdecl *_CRT_ALLOC_HOOK)(int,void *,size_t,int,long,const unsigned char *,int);

#define _CRTDBG_ALLOC_MEM_DF 0x01
#define _CRTDBG_DELAY_FREE_MEM_DF 0x02
#define _CRTDBG_CHECK_ALWAYS_DF 0x04
#define _CRTDBG_RESERVED_DF 0x08
#define _CRTDBG_CHECK_CRT_DF 0x10
#define _CRTDBG_LEAK_CHECK_DF 0x20

#define _CRTDBG_CHECK_EVERY_16_DF 0x00100000
#define _CRTDBG_CHECK_EVERY_128_DF 0x00800000
#define _CRTDBG_CHECK_EVERY_1024_DF 0x04000000

#define _CRTDBG_CHECK_DEFAULT_DF 0

#define _CRTDBG_REPORT_FLAG -1

#define _BLOCK_TYPE(block) (block & 0xFFFF)
#define _BLOCK_SUBTYPE(block) (block >> 16 & 0xFFFF)

#define _FREE_BLOCK 0
#define _NORMAL_BLOCK 1
#define _CRT_BLOCK 2
#define _IGNORE_BLOCK 3
#define _CLIENT_BLOCK 4
#define _MAX_BLOCKS 5

  typedef void (__cdecl *_CRT_DUMP_CLIENT)(void *,size_t);

  struct _CrtMemBlockHeader;

  typedef struct _CrtMemState {
    struct _CrtMemBlockHeader *pBlockHeader;
    size_t lCounts[_MAX_BLOCKS];
    size_t lSizes[_MAX_BLOCKS];
    size_t lHighWaterCount;
    size_t lTotalCount;
  } _CrtMemState;

#ifndef _STATIC_ASSERT
#if defined(_MSC_VER)
#define _STATIC_ASSERT(expr) typedef char __static_assert_t[(expr)]
#else
#define _STATIC_ASSERT(expr) extern void __static_assert_t(int [(expr)?1:-1])
#endif
#endif

#ifndef _ASSERT
#define _ASSERT(expr) ((void)0)
#endif

#ifndef _ASSERTE
#define _ASSERTE(expr) ((void)0)
#endif

#ifndef _ASSERT_EXPR
#define _ASSERT_EXPR(expr,expr_str) ((void)0)
#endif

#ifndef _ASSERT_BASE
#define _ASSERT_BASE _ASSERT_EXPR
#endif

#define _RPT0(rptno,msg)
#define _RPTW0(rptno,msg)

#define _RPT1(rptno,msg,arg1)
#define _RPTW1(rptno,msg,arg1)
#define _RPT2(rptno,msg,arg1,arg2)
#define _RPTW2(rptno,msg,arg1,arg2)
#define _RPT3(rptno,msg,arg1,arg2,arg3)
#define _RPTW3(rptno,msg,arg1,arg2,arg3)
#define _RPT4(rptno,msg,arg1,arg2,arg3,arg4)
#define _RPTW4(rptno,msg,arg1,arg2,arg3,arg4)
#define _RPTF0(rptno,msg)
#define _RPTFW0(rptno,msg)
#define _RPTF1(rptno,msg,arg1)
#define _RPTFW1(rptno,msg,arg1)
#define _RPTF2(rptno,msg,arg1,arg2)
#define _RPTFW2(rptno,msg,arg1,arg2)
#define _RPTF3(rptno,msg,arg1,arg2,arg3)
#define _RPTFW3(rptno,msg,arg1,arg2,arg3)
#define _RPTF4(rptno,msg,arg1,arg2,arg3,arg4)
#define _RPTFW4(rptno,msg,arg1,arg2,arg3,arg4)

#define _malloc_dbg(s,t,f,l) malloc(s)
#define _calloc_dbg(c,s,t,f,l) calloc(c,s)
#define _realloc_dbg(p,s,t,f,l) realloc(p,s)
#define _recalloc_dbg(p,c,s,t,f,l) _recalloc(p,c,s)
#define _expand_dbg(p,s,t,f,l) _expand(p,s)
#define _free_dbg(p,t) free(p)
#define _msize_dbg(p,t) _msize(p)

#define _aligned_malloc_dbg(s,a,f,l) _aligned_malloc(s,a)
#define _aligned_realloc_dbg(p,s,a,f,l) _aligned_realloc(p,s,a)
#define _aligned_recalloc_dbg(p,c,s,a,f,l) _aligned_realloc(p,c,s,a)
#define _aligned_free_dbg(p) _aligned_free(p)
#define _aligned_offset_malloc_dbg(s,a,o,f,l) _aligned_offset_malloc(s,a,o)
#define _aligned_offset_realloc_dbg(p,s,a,o,f,l) _aligned_offset_realloc(p,s,a,o)
#define _aligned_offset_recalloc_dbg(p,c,s,a,o,f,l) _aligned_offset_recalloc(p,c,s,a,o)

#define _malloca_dbg(s,t,f,l) _malloca(s)
#define _freea_dbg(p,t) _freea(p)

#define _strdup_dbg(s,t,f,l) _strdup(s)
#define _wcsdup_dbg(s,t,f,l) _wcsdup(s)
#define _mbsdup_dbg(s,t,f,l) _mbsdup(s)
#define _tempnam_dbg(s1,s2,t,f,l) _tempnam(s1,s2)
#define _wtempnam_dbg(s1,s2,t,f,l) _wtempnam(s1,s2)
#define _fullpath_dbg(s1,s2,le,t,f,l) _fullpath(s1,s2,le)
#define _wfullpath_dbg(s1,s2,le,t,f,l) _wfullpath(s1,s2,le)
#define _getcwd_dbg(s,le,t,f,l) _getcwd(s,le)
#define _wgetcwd_dbg(s,le,t,f,l) _wgetcwd(s,le)
#define _getdcwd_dbg(d,s,le,t,f,l) _getdcwd(d,s,le)
#define _wgetdcwd_dbg(d,s,le,t,f,l) _wgetdcwd(d,s,le)
#if __MSVCRT_VERSION__ >= 0x800
#define _getdcwd_lk_dbg(d,s,le,t,f,l) _getdcwd_nolock(d,s,le)
#define _wgetdcwd_lk_dbg(d,s,le,t,f,l) _wgetdcwd_nolock(d,s,le)
#endif

#define _CrtSetReportHook(f) ((_CRT_REPORT_HOOK)0)
#define _CrtGetReportHook() ((_CRT_REPORT_HOOK)0)
#define _CrtSetReportHook2(t,f) ((int)0)
#define _CrtSetReportHookW2(t,f) ((int)0)
#define _CrtSetReportMode(t,f) ((int)0)
#define _CrtSetReportFile(t,f) ((_HFILE)0)

#define _CrtDbgBreak() ((void)0)

#define _CrtSetBreakAlloc(a) ((long)0)
#define _CrtSetAllocHook(f) ((_CRT_ALLOC_HOOK)0)
#define _CrtGetAllocHook() ((_CRT_ALLOC_HOOK)0)
#define _CrtCheckMemory() ((int)1)
#define _CrtSetDbgFlag(f) ((int)0)
#define _CrtDoForAllClientObjects(f,c) ((void)0)
#define _CrtIsValidPointer(p,n,r) ((int)1)
#define _CrtIsValidHeapPointer(p) ((int)1)
#define _CrtIsMemoryBlock(p,t,r,f,l) ((int)1)
#define _CrtReportBlockType(p) ((int)-1)
#define _CrtSetDumpClient(f) ((_CRT_DUMP_CLIENT)0)
#define _CrtGetDumpClient() ((_CRT_DUMP_CLIENT)0)
#define _CrtMemCheckpoint(s) ((void)0)
#define _CrtMemDifference(s1,s2,s3) ((int)0)
#define _CrtMemDumpAllObjectsSince(s) ((void)0)
#define _CrtMemDumpStatistics(s) ((void)0)
#define _CrtDumpMemoryLeaks() ((int)0)
#define _CrtSetDebugFillThreshold(t) ((size_t)0)
#define _CrtSetCheckCount(f) ((int)0)
#define _CrtGetCheckCount() ((int)0)

#ifdef __cplusplus
}
/*
  void *__cdecl operator new[](size_t _Size);
  inline void *__cdecl operator new(size_t _Size,int,const char *,int) { return ::operator new(_Size); }
  inline void *__cdecl operator new[](size_t _Size,int,const char *,int) { return ::operator new[](_Size); }
  void __cdecl operator delete[](void *);
  inline void __cdecl operator delete(void *_P,int,const char *,int) { ::operator delete(_P); }
  inline void __cdecl operator delete[](void *_P,int,const char *,int) { ::operator delete[](_P); }
 */
#endif

#pragma pack(pop)

#include <sec_api/crtdbg_s.h>

#endif
