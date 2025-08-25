/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_SEARCH_S
#define _INC_SEARCH_S

#include <search.h>

#ifdef __cplusplus
extern "C" {
#endif

  _CRTIMP void *__cdecl _lfind_s(const void *_Key,const void *_Base,unsigned int *_NumOfElements,size_t _SizeOfElements,int (__cdecl *_PtFuncCompare)(void *,const void *,const void *),void *_Context);
  _CRTIMP void *__cdecl _lsearch_s(const void *_Key,void *_Base,unsigned int *_NumOfElements,size_t _SizeOfElements,int (__cdecl *_PtFuncCompare)(void *,const void *,const void *),void *_Context);

#ifndef _QSORT_S_DEFINED
#define _QSORT_S_DEFINED
  _CRTIMP void __cdecl qsort_s(void *_Base,size_t _NumOfElements,size_t _SizeOfElements,int (__cdecl *_PtFuncCompare)(void *,const void *,const void *),void *_Context);
#endif

#ifdef __cplusplus
}
#endif

#endif
