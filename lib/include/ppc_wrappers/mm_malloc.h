/*===---- mm_malloc.h - Implementation of _mm_malloc and _mm_free ----------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef _MM_MALLOC_H_INCLUDED
#define _MM_MALLOC_H_INCLUDED

#include <stdlib.h>

/* We can't depend on <stdlib.h> since the prototype of posix_memalign
   may not be visible.  */
#ifndef __cplusplus
extern int posix_memalign (void **, size_t, size_t);
#else
extern "C" int posix_memalign (void **, size_t, size_t) throw ();
#endif

static __inline void *
_mm_malloc (size_t size, size_t alignment)
{
  /* PowerPC64 ELF V2 ABI requires quadword alignment.  */
  size_t vec_align = sizeof (__vector float);
  void *ptr;

  if (alignment < vec_align)
    alignment = vec_align;
  if (posix_memalign (&ptr, alignment, size) == 0)
    return ptr;
  else
    return NULL;
}

static __inline void
_mm_free (void * ptr)
{
  free (ptr);
}

#endif /* _MM_MALLOC_H_INCLUDED */
