/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MALLOC_H_
#define _MALLOC_H_

#include <crtdefs.h>

#pragma pack(push,_CRT_PACKING)

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN64
#define _HEAP_MAXREQ 0xFFFFFFFFFFFFFFE0
#else
#define _HEAP_MAXREQ 0xFFFFFFE0
#endif

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

/* Return codes for _heapwalk()  */
#define _HEAPEMPTY (-1)
#define _HEAPOK (-2)
#define _HEAPBADBEGIN (-3)
#define _HEAPBADNODE (-4)
#define _HEAPEND (-5)
#define _HEAPBADPTR (-6)

/* Values for _heapinfo.useflag */
#define _FREEENTRY 0
#define _USEDENTRY 1

#ifndef _HEAPINFO_DEFINED
#define _HEAPINFO_DEFINED
 /* The structure used to walk through the heap with _heapwalk.  */
  typedef struct _heapinfo {
    int *_pentry;
    size_t _size;
    int _useflag;
  } _HEAPINFO;
#endif

#define _amblksiz (*__p__amblksiz())
  _CRTIMP unsigned int *__cdecl __p__amblksiz(void);

#ifndef _CRT_ALLOCATION_DEFINED
#define _CRT_ALLOCATION_DEFINED

#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma push_macro("calloc")
#undef calloc
#pragma push_macro("free")
#undef free
#pragma push_macro("malloc")
#undef malloc
#pragma push_macro("realloc")
#undef realloc
#pragma push_macro("_aligned_free")
#undef _aligned_free
#pragma push_macro("_aligned_malloc")
#undef _aligned_malloc
#pragma push_macro("_aligned_offset_malloc")
#undef _aligned_offset_malloc
#pragma push_macro("_aligned_realloc")
#undef _aligned_realloc
#pragma push_macro("_aligned_offset_realloc")
#undef _aligned_offset_realloc
#pragma push_macro("_recalloc")
#undef _recalloc
#pragma push_macro("_aligned_recalloc")
#undef _aligned_recalloc
#pragma push_macro("_aligned_offset_recalloc")
#undef _aligned_offset_recalloc
#pragma push_macro("_aligned_msize")
#undef _aligned_msize
#endif

  void *__cdecl calloc(size_t _NumOfElements,size_t _SizeOfElements);
  void __cdecl free(void *_Memory);
  void *__cdecl malloc(size_t _Size);
  void *__cdecl realloc(void *_Memory,size_t _NewSize);

  _CRTIMP void __cdecl _aligned_free(void *_Memory);
  _CRTIMP void *__cdecl _aligned_malloc(size_t _Size,size_t _Alignment);

  _CRTIMP void *__cdecl _aligned_offset_malloc(size_t _Size,size_t _Alignment,size_t _Offset);
  _CRTIMP void *__cdecl _aligned_realloc(void *_Memory,size_t _Size,size_t _Alignment);
  _CRTIMP void *__cdecl _aligned_offset_realloc(void *_Memory,size_t _Size,size_t _Alignment,size_t _Offset);
  _CRTIMP void *__cdecl _recalloc(void *_Memory,size_t _Count,size_t _Size);
  _CRTIMP void *__cdecl _aligned_recalloc(void *_Memory,size_t _Count,size_t _Size,size_t _Alignment);
  _CRTIMP void *__cdecl _aligned_offset_recalloc(void *_Memory,size_t _Count,size_t _Size,size_t _Alignment,size_t _Offset);
  _CRTIMP size_t __cdecl _aligned_msize(void *_Memory,size_t _Alignment,size_t _Offset);

#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma pop_macro("calloc")
#pragma pop_macro("free")
#pragma pop_macro("malloc")
#pragma pop_macro("realloc")
#pragma pop_macro("_aligned_free")
#pragma pop_macro("_aligned_malloc")
#pragma pop_macro("_aligned_offset_malloc")
#pragma pop_macro("_aligned_realloc")
#pragma pop_macro("_aligned_offset_realloc")
#pragma pop_macro("_recalloc")
#pragma pop_macro("_aligned_recalloc")
#pragma pop_macro("_aligned_offset_recalloc")
#pragma pop_macro("_aligned_msize")
#endif

#endif

/* Users should really use MS provided versions */
void * __mingw_aligned_malloc (size_t _Size, size_t _Alignment);
void __mingw_aligned_free (void *_Memory);
void * __mingw_aligned_offset_realloc (void *_Memory, size_t _Size, size_t _Alignment, size_t _Offset);
void * __mingw_aligned_offset_malloc (size_t, size_t, size_t);
void * __mingw_aligned_realloc (void *_Memory, size_t _Size, size_t _Offset);
size_t __mingw_aligned_msize (void *memblock, size_t alignment, size_t offset);

#if defined(__x86_64__) || defined(__i386__)
/* Get the compiler's definition of _mm_malloc and _mm_free. */
#include <mm_malloc.h>
#endif

#define _MAX_WAIT_MALLOC_CRT 60000

#ifdef _CRT_USE_WINAPI_FAMILY_DESKTOP_APP
  _CRTIMP int __cdecl _resetstkoflw (void);
#endif /* _CRT_USE_WINAPI_FAMILY_DESKTOP_APP */
  _CRTIMP unsigned long __cdecl _set_malloc_crt_max_wait(unsigned long _NewValue);

#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma push_macro("_expand")
#undef _expand
#pragma push_macro("_msize")
#undef _msize
#endif
  _CRTIMP void *__cdecl _expand(void *_Memory,size_t _NewSize);
  _CRTIMP size_t __cdecl _msize(void *_Memory);
#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma pop_macro("_expand")
#pragma pop_macro("_msize")
#endif

#ifdef __GNUC__
#undef _alloca
#define _alloca(x) __builtin_alloca((x))
#else
  void *__cdecl _alloca(size_t _Size) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#endif
  _CRTIMP size_t __cdecl _get_sbh_threshold(void);
  _CRTIMP int __cdecl _set_sbh_threshold(size_t _NewValue);
  _CRTIMP errno_t __cdecl _set_amblksiz(size_t _Value);
  _CRTIMP errno_t __cdecl _get_amblksiz(size_t *_Value);
  _CRTIMP int __cdecl _heapadd(void *_Memory,size_t _Size);
  _CRTIMP int __cdecl _heapchk(void);
  _CRTIMP int __cdecl _heapmin(void);
  _CRTIMP int __cdecl _heapset(unsigned int _Fill);
  _CRTIMP int __cdecl _heapwalk(_HEAPINFO *_EntryInfo);
  _CRTIMP size_t __cdecl _heapused(size_t *_Used,size_t *_Commit);
  _CRTIMP intptr_t __cdecl _get_heap_handle(void);

#define _ALLOCA_S_THRESHOLD 1024
#define _ALLOCA_S_STACK_MARKER 0xCCCC
#define _ALLOCA_S_HEAP_MARKER 0xDDDD

#if defined(_ARM_) || (defined(_X86_) && !defined(__x86_64))
#define _ALLOCA_S_MARKER_SIZE 8
#elif defined(__ia64__) || defined(__x86_64) || defined(__aarch64__)
#define _ALLOCA_S_MARKER_SIZE 16
#endif

#if !defined(RC_INVOKED)
  static __inline void *_MarkAllocaS(void *_Ptr,unsigned int _Marker) {
    if(_Ptr) {
      *((unsigned int*)_Ptr) = _Marker;
      _Ptr = (char*)_Ptr + _ALLOCA_S_MARKER_SIZE;
    }
    return _Ptr;
  }
#endif

#ifdef _DEBUG
#ifndef _CRTDBG_MAP_ALLOC
#undef _malloca
#define _malloca(size) \
    _MarkAllocaS(malloc((size) + _ALLOCA_S_MARKER_SIZE), _ALLOCA_S_HEAP_MARKER)
#endif
#else
#undef _malloca
#define _malloca(size) \
  ((((size) + _ALLOCA_S_MARKER_SIZE) <= _ALLOCA_S_THRESHOLD) ? \
    _MarkAllocaS(_alloca((size) + _ALLOCA_S_MARKER_SIZE),_ALLOCA_S_STACK_MARKER) : \
    _MarkAllocaS(malloc((size) + _ALLOCA_S_MARKER_SIZE),_ALLOCA_S_HEAP_MARKER))
#endif

#undef _FREEA_INLINE
#define _FREEA_INLINE

#ifndef RC_INVOKED
#undef _freea
  static __inline void __cdecl _freea(void *_Memory) {
    unsigned int _Marker;
    if(_Memory) {
      _Memory = (char*)_Memory - _ALLOCA_S_MARKER_SIZE;
      _Marker = *(unsigned int *)_Memory;
      if(_Marker==_ALLOCA_S_HEAP_MARKER) {
	free(_Memory);
      }
#ifdef _ASSERTE
      else if(_Marker!=_ALLOCA_S_STACK_MARKER) {
	_ASSERTE(("Corrupted pointer passed to _freea",0));
      }
#endif
    }
  }
#endif /* RC_INVOKED */

#ifndef	NO_OLDNAMES
#undef alloca
#ifdef __GNUC__
#define alloca(x) __builtin_alloca((x))
#else
#define alloca _alloca
#endif
#endif

#ifdef HEAPHOOK
#ifndef _HEAPHOOK_DEFINED
#define _HEAPHOOK_DEFINED
  typedef int (__cdecl *_HEAPHOOK)(int,size_t,void *,void **);
#endif

  _CRTIMP _HEAPHOOK __cdecl _setheaphook(_HEAPHOOK _NewHook);

#define _HEAP_MALLOC 1
#define _HEAP_CALLOC 2
#define _HEAP_FREE 3
#define _HEAP_REALLOC 4
#define _HEAP_MSIZE 5
#define _HEAP_EXPAND 6
#endif

#ifdef __cplusplus
}
#endif

#pragma pack(pop)

#endif /* _MALLOC_H_ */
