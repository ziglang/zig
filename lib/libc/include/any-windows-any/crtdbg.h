/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <crtdefs.h>
#include <sal.h>

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
#if (defined(__cpp_static_assert) && __cpp_static_assert >= 201411L) || (defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L)
#define _STATIC_ASSERT(expr) static_assert(expr)
#elif defined(__cpp_static_assert)
#define _STATIC_ASSERT(expr) static_assert(expr, #expr)
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
#define _STATIC_ASSERT(expr) _Static_assert(expr, #expr)
#elif defined(_MSC_VER)
#define _STATIC_ASSERT(expr) typedef char __static_assert_t[(expr)]
#else
#define _STATIC_ASSERT(expr) extern void __static_assert_t(int [(expr)?1:-1])
#endif
#endif

#ifndef _DEBUG

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
#define _expand_dbg(p,s,t,f,l) _expand(p,s)
#define _free_dbg(p,t) free(p)
#define _msize_dbg(p,t) _msize(p)

#define _aligned_malloc_dbg(s,a,f,l) _aligned_malloc(s,a)
#define _aligned_realloc_dbg(p,s,a,f,l) _aligned_realloc(p,s,a)
#define _aligned_free_dbg(p) _aligned_free(p)
#define _aligned_offset_malloc_dbg(s,a,o,f,l) _aligned_offset_malloc(s,a,o)
#define _aligned_offset_realloc_dbg(p,s,a,o,f,l) _aligned_offset_realloc(p,s,a,o)

#define _recalloc_dbg(p,c,s,t,f,l) _recalloc(p,c,s)
#define _aligned_recalloc_dbg(p,c,s,a,f,l) _aligned_realloc(p,c,s,a)
#define _aligned_offset_recalloc_dbg(p,c,s,a,o,f,l) _aligned_offset_recalloc(p,c,s,a,o)
#define _aligned_msize_dbg(p,a,o) _aligned_msize(p,a,o)

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

#else /* _DEBUG */

_CRTIMP long * __cdecl __p__crtAssertBusy(void);
#define _crtAssertBusy (*__p__crtAssertBusy())

_CRTIMP _CRT_REPORT_HOOK __cdecl _CrtGetReportHook(void);
_CRTIMP _CRT_REPORT_HOOK __cdecl _CrtSetReportHook(_CRT_REPORT_HOOK _PFnNewHook);
_CRTIMP int __cdecl _CrtSetReportHook2(int _Mode, _CRT_REPORT_HOOK _PFnNewHook);
_CRTIMP int __cdecl _CrtSetReportHookW2(int _Mode, _CRT_REPORT_HOOKW _PFnNewHook);
_CRTIMP int __cdecl _CrtSetReportMode(int _ReportType, int _ReportMode);
_CRTIMP _HFILE __cdecl _CrtSetReportFile(int _ReportType, _HFILE _ReportFile);
_CRTIMP int __cdecl _CrtDbgReport(int _ReportType, const char * _Filename, int _Linenumber, const char * _ModuleName, const char * _Format, ...);
_CRTIMP size_t __cdecl _CrtSetDebugFillThreshold(size_t _NewDebugFillThreshold);
_CRTIMP int __cdecl _CrtDbgReportW(int _ReportType, const wchar_t * _Filename, int _LineNumber, const wchar_t * _ModuleName, const wchar_t * _Format, ...);

#define _ASSERT_EXPR(expr, msg) \
        (void) ((!!(expr)) || \
                (1 != _CrtDbgReportW(_CRT_ASSERT, _CRT_WIDE(__FILE__), __LINE__, NULL, msg)) || \
                (_CrtDbgBreak(), 0))

#ifndef _ASSERT
#define _ASSERT(expr)   _ASSERT_EXPR((expr), NULL)
#endif

#ifndef _ASSERTE
#define _ASSERTE(expr)  _ASSERT_EXPR((expr), _CRT_WIDE(#expr))
#endif

#ifndef _ASSERT_BASE
#define _ASSERT_BASE _ASSERT_EXPR
#endif

#define _RPT_BASE(args) \
        (void) ((1 != _CrtDbgReport args) || \
                (_CrtDbgBreak(), 0))

#define _RPT_BASE_W(args) \
        (void) ((1 != _CrtDbgReportW args) || \
                (_CrtDbgBreak(), 0))

#define _RPT0(rptno, msg) \
        _RPT_BASE((rptno, NULL, 0, NULL, "%s", msg))

#define _RPTW0(rptno, msg) \
        _RPT_BASE_W((rptno, NULL, 0, NULL, L"%s", msg))

#define _RPT1(rptno, msg, arg1) \
        _RPT_BASE((rptno, NULL, 0, NULL, msg, arg1))

#define _RPTW1(rptno, msg, arg1) \
        _RPT_BASE_W((rptno, NULL, 0, NULL, msg, arg1))

#define _RPT2(rptno, msg, arg1, arg2) \
        _RPT_BASE((rptno, NULL, 0, NULL, msg, arg1, arg2))

#define _RPTW2(rptno, msg, arg1, arg2) \
        _RPT_BASE_W((rptno, NULL, 0, NULL, msg, arg1, arg2))

#define _RPT3(rptno, msg, arg1, arg2, arg3) \
        _RPT_BASE((rptno, NULL, 0, NULL, msg, arg1, arg2, arg3))

#define _RPTW3(rptno, msg, arg1, arg2, arg3) \
        _RPT_BASE_W((rptno, NULL, 0, NULL, msg, arg1, arg2, arg3))

#define _RPT4(rptno, msg, arg1, arg2, arg3, arg4) \
        _RPT_BASE((rptno, NULL, 0, NULL, msg, arg1, arg2, arg3, arg4))

#define _RPTW4(rptno, msg, arg1, arg2, arg3, arg4) \
        _RPT_BASE_W((rptno, NULL, 0, NULL, msg, arg1, arg2, arg3, arg4))

#define _RPT5(rptno, msg, arg1, arg2, arg3, arg4, arg5) \
        _RPT_BASE((rptno, NULL, 0, NULL, msg, arg1, arg2, arg3, arg4, arg5))

#define _RPTW5(rptno, msg, arg1, arg2, arg3, arg4, arg5) \
        _RPT_BASE_W((rptno, NULL, 0, NULL, msg, arg1, arg2, arg3, arg4, arg5))

#define _RPTF0(rptno, msg) \
        _RPT_BASE((rptno, __FILE__, __LINE__, NULL, "%s", msg))

#define _RPTFW0(rptno, msg) \
        _RPT_BASE_W((rptno, _CRT_WIDE(__FILE__), __LINE__, NULL, L"%s", msg))

#define _RPTF1(rptno, msg, arg1) \
        _RPT_BASE((rptno, __FILE__, __LINE__, NULL, msg, arg1))

#define _RPTFW1(rptno, msg, arg1) \
        _RPT_BASE_W((rptno, _CRT_WIDE(__FILE__), __LINE__, NULL, msg, arg1))

#define _RPTF2(rptno, msg, arg1, arg2) \
        _RPT_BASE((rptno, __FILE__, __LINE__, NULL, msg, arg1, arg2))

#define _RPTFW2(rptno, msg, arg1, arg2) \
        _RPT_BASE_W((rptno, _CRT_WIDE(__FILE__), __LINE__, NULL, msg, arg1, arg2))

#define _RPTF3(rptno, msg, arg1, arg2, arg3) \
        _RPT_BASE((rptno, __FILE__, __LINE__, NULL, msg, arg1, arg2, arg3))

#define _RPTFW3(rptno, msg, arg1, arg2, arg3) \
        _RPT_BASE_W((rptno, _CRT_WIDE(__FILE__), __LINE__, NULL, msg, arg1, arg2, arg3))

#define _RPTF4(rptno, msg, arg1, arg2, arg3, arg4) \
        _RPT_BASE((rptno, __FILE__, __LINE__, NULL, msg, arg1, arg2, arg3, arg4))

#define _RPTFW4(rptno, msg, arg1, arg2, arg3, arg4) \
        _RPT_BASE_W((rptno, _CRT_WIDE(__FILE__), __LINE__, NULL, msg, arg1, arg2, arg3, arg4))

#define _RPTF5(rptno, msg, arg1, arg2, arg3, arg4, arg5) \
        _RPT_BASE((rptno, __FILE__, __LINE__, NULL, msg, arg1, arg2, arg3, arg4, arg5))

#define _RPTFW5(rptno, msg, arg1, arg2, arg3, arg4, arg5) \
        _RPT_BASE_W((rptno, _CRT_WIDE(__FILE__), __LINE__, NULL, msg, arg1, arg2, arg3, arg4, arg5))

#define _CrtDbgBreak() __debugbreak()

#ifdef _CRTDBG_MAP_ALLOC

#define   malloc(s)             _malloc_dbg(s, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   calloc(c, s)          _calloc_dbg(c, s, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   realloc(p, s)         _realloc_dbg(p, s, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _recalloc(p, c, s)    _recalloc_dbg(p, c, s, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _expand(p, s)         _expand_dbg(p, s, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   free(p)               _free_dbg(p, _NORMAL_BLOCK)
#define   _msize(p)             _msize_dbg(p, _NORMAL_BLOCK)
#define   _aligned_msize(p, a, o)                   _aligned_msize_dbg(p, a, o)
#define   _aligned_malloc(s, a)                     _aligned_malloc_dbg(s, a, __FILE__, __LINE__)
#define   _aligned_realloc(p, s, a)                 _aligned_realloc_dbg(p, s, a, __FILE__, __LINE__)
#define   _aligned_recalloc(p, c, s, a)             _aligned_recalloc_dbg(p, c, s, a, __FILE__, __LINE__)
#define   _aligned_offset_malloc(s, a, o)           _aligned_offset_malloc_dbg(s, a, o, __FILE__, __LINE__)
#define   _aligned_offset_realloc(p, s, a, o)       _aligned_offset_realloc_dbg(p, s, a, o, __FILE__, __LINE__)
#define   _aligned_offset_recalloc(p, c, s, a, o)   _aligned_offset_recalloc_dbg(p, c, s, a, o, __FILE__, __LINE__)
#define   _aligned_free(p)  _aligned_free_dbg(p)

#define   _malloca(s)        _malloca_dbg(s, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _freea(p)          _freea_dbg(p, _NORMAL_BLOCK)

#define   _strdup(s)         _strdup_dbg(s, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _wcsdup(s)         _wcsdup_dbg(s, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _mbsdup(s)         _strdup_dbg(s, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _tempnam(s1, s2)   _tempnam_dbg(s1, s2, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _wtempnam(s1, s2)  _wtempnam_dbg(s1, s2, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _fullpath(s1, s2, le)     _fullpath_dbg(s1, s2, le, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _wfullpath(s1, s2, le)    _wfullpath_dbg(s1, s2, le, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _getcwd(s, le)      _getcwd_dbg(s, le, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _wgetcwd(s, le)     _wgetcwd_dbg(s, le, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _getdcwd(d, s, le)  _getdcwd_dbg(d, s, le, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _wgetdcwd(d, s, le) _wgetdcwd_dbg(d, s, le, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _getdcwd_nolock(d, s, le)     _getdcwd_lk_dbg(d, s, le, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _wgetdcwd_nolock(d, s, le)    _wgetdcwd_lk_dbg(d, s, le, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _dupenv_s(ps1, size, s2)      _dupenv_s_dbg(ps1, size, s2, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   _wdupenv_s(ps1, size, s2)     _wdupenv_s_dbg(ps1, size, s2, _NORMAL_BLOCK, __FILE__, __LINE__)

#define   strdup(s)          _strdup_dbg(s, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   wcsdup(s)          _wcsdup_dbg(s, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   tempnam(s1, s2)    _tempnam_dbg(s1, s2, _NORMAL_BLOCK, __FILE__, __LINE__)
#define   getcwd(s, le)      _getcwd_dbg(s, le, _NORMAL_BLOCK, __FILE__, __LINE__)

#endif  /* _CRTDBG_MAP_ALLOC */

_CRTIMP long * __cdecl __p__crtBreakAlloc(void);
#define _crtBreakAlloc (*__p__crtBreakAlloc())

_CRTIMP long __cdecl _CrtSetBreakAlloc(long _BreakAlloc);

_CRTIMP __checkReturn void * __cdecl _malloc_dbg(size_t _Size, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn void * __cdecl _calloc_dbg(size_t _NumOfElements, size_t _SizeOfElements, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn void * __cdecl _realloc_dbg(void * _Memory, size_t _NewSize, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn void * __cdecl _recalloc_dbg(void * _Memory, size_t _NumOfElements, size_t _SizeOfElements, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn void * __cdecl _expand_dbg(void * _Memory, size_t _NewSize, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP void __cdecl _free_dbg(void * _Memory, int _BlockType);
_CRTIMP size_t __cdecl _msize_dbg(void * _Memory, int _BlockType);
_CRTIMP size_t __cdecl _aligned_msize_dbg(void * _Memory, size_t _Alignment, size_t _Offset);
_CRTIMP __checkReturn void * __cdecl _aligned_malloc_dbg(size_t _Size, size_t _Alignment, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn void * __cdecl _aligned_realloc_dbg(void * _Memory, size_t _Size, size_t _Alignment, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn void * __cdecl _aligned_recalloc_dbg(void * _Memory, size_t _NumOfElements, size_t _SizeOfElements, size_t _Alignment, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn void * __cdecl _aligned_offset_malloc_dbg(size_t _Size, size_t _Alignment, size_t _Offset, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn void * __cdecl _aligned_offset_realloc_dbg(void * _Memory, size_t _Size, size_t _Alignment, size_t _Offset, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn void * __cdecl _aligned_offset_recalloc_dbg(void * _Memory, size_t _NumOfElements, size_t _SizeOfElements, size_t _Alignment, size_t _Offset, const char * _Filename, int _LineNumber);
_CRTIMP void __cdecl _aligned_free_dbg(void * _Memory);
_CRTIMP __checkReturn char * __cdecl _strdup_dbg(const char * _Str, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn wchar_t * __cdecl _wcsdup_dbg(const wchar_t * _Str, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn char * __cdecl _tempnam_dbg(const char * _DirName, const char * _FilePrefix, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn wchar_t * __cdecl _wtempnam_dbg(const wchar_t * _DirName, const wchar_t * _FilePrefix, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn char * __cdecl _fullpath_dbg(char * _FullPath, const char * _Path, size_t _SizeInBytes, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn wchar_t * __cdecl _wfullpath_dbg(wchar_t * _FullPath, const wchar_t * _Path, size_t _SizeInWords, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn char * __cdecl _getcwd_dbg(char * _DstBuf, int _SizeInBytes, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn wchar_t * __cdecl _wgetcwd_dbg(wchar_t * _DstBuf, int _SizeInWords, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn char * __cdecl _getdcwd_dbg(int _Drive, char * _DstBuf, int _SizeInBytes, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn wchar_t * __cdecl _wgetdcwd_dbg(int _Drive, wchar_t * _DstBuf, int _SizeInWords, int _BlockType, const char * _Filename, int _LineNumber);
__checkReturn char * __cdecl _getdcwd_lk_dbg(int _Drive, char * _DstBuf, int _SizeInBytes, int _BlockType, const char * _Filename, int _LineNumber);
__checkReturn wchar_t * __cdecl _wgetdcwd_lk_dbg(int _Drive, wchar_t * _DstBuf, int _SizeInWords, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn errno_t __cdecl _dupenv_s_dbg(char ** _PBuffer, size_t * _PBufferSizeInBytes, const char * _VarName, int _BlockType, const char * _Filename, int _LineNumber);
_CRTIMP __checkReturn errno_t __cdecl _wdupenv_s_dbg(wchar_t ** _PBuffer, size_t * _PBufferSizeInWords, const wchar_t * _VarName, int _BlockType, const char * _Filename, int _LineNumber);

#define _malloca_dbg(s, t, f, l)    _malloc_dbg(s, t, f, l)
#define _freea_dbg(p, t)            _free_dbg(p, t)

_CRTIMP _CRT_ALLOC_HOOK __cdecl _CrtGetAllocHook(void);
_CRTIMP _CRT_ALLOC_HOOK __cdecl _CrtSetAllocHook(_CRT_ALLOC_HOOK _PfnNewHook);

_CRTIMP int * __cdecl __p__crtDbgFlag(void);
#define _crtDbgFlag (*__p__crtDbgFlag())

_CRTIMP int __cdecl _CrtCheckMemory(void);
_CRTIMP int __cdecl _CrtSetDbgFlag(int _NewFlag);
_CRTIMP void __cdecl _CrtDoForAllClientObjects(void (__cdecl *_PFn)(void *, void *), void * _Context);
_CRTIMP __checkReturn int __cdecl _CrtIsValidPointer(const void * _Ptr, unsigned int _Bytes, int _ReadWrite);
_CRTIMP __checkReturn int __cdecl _CrtIsValidHeapPointer(const void * _HeapPtr);
_CRTIMP int __cdecl _CrtIsMemoryBlock(const void * _Memory, unsigned int _Bytes, long * _RequestNumber, char ** _Filename, int * _LineNumber);
_CRTIMP __checkReturn int __cdecl _CrtReportBlockType(const void * _Memory);
_CRTIMP _CRT_DUMP_CLIENT __cdecl _CrtGetDumpClient(void);
_CRTIMP _CRT_DUMP_CLIENT __cdecl _CrtSetDumpClient(_CRT_DUMP_CLIENT _PFnNewDump);
_CRTIMP _CRT_MANAGED_HEAP_DEPRECATE void __cdecl _CrtMemCheckpoint(_CrtMemState * _State);
_CRTIMP _CRT_MANAGED_HEAP_DEPRECATE int __cdecl _CrtMemDifference(_CrtMemState * _State, const _CrtMemState * _OldState, const _CrtMemState * _NewState);
_CRTIMP void __cdecl _CrtMemDumpAllObjectsSince(const _CrtMemState * _State);
_CRTIMP void __cdecl _CrtMemDumpStatistics(const _CrtMemState * _State);
_CRTIMP int __cdecl _CrtDumpMemoryLeaks(void);
_CRTIMP int __cdecl _CrtSetCheckCount(int _CheckCount);
_CRTIMP int __cdecl _CrtGetCheckCount(void);

#endif /* _DEBUG */

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
