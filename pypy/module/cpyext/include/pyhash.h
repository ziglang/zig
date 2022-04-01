#ifndef Py_HASH_H

#define Py_HASH_H
#ifdef __cplusplus
extern "C" {
#endif

/* Keep synced with rpython/rlib/objectmodel.py */

/* Prime multiplier used in string and various other hashes. */
#define _PyHASH_MULTIPLIER 1000003UL  /* 0xf4243 */

/* Parameters used for the numeric hash implementation.  See notes for
   _Py_HashDouble in Python/pyhash.c.  Numeric hashes are based on
   reduction modulo the prime 2**_PyHASH_BITS - 1. */

#if SIZEOF_VOID_P >= 8
#  define _PyHASH_BITS 61
#else
#  define _PyHASH_BITS 31
#endif

#define _PyHASH_MODULUS (((size_t)1 << _PyHASH_BITS) - 1)
#define _PyHASH_INF 314159
#define _PyHASH_NAN 0
#define _PyHASH_IMAG _PyHASH_MULTIPLIER


#ifdef __cplusplus
}
#endif

#endif /* !Py_HASH_H */
