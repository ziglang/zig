#include <stdlib.h>

#ifndef Py_PYMEM_H
#define Py_PYMEM_H

#ifdef __cplusplus
extern "C" {
#endif

#ifndef Py_LIMITED_API
PyAPI_FUNC(void *) PyMem_RawMalloc(size_t size);
PyAPI_FUNC(void *) PyMem_RawCalloc(size_t nelem, size_t elsize);
PyAPI_FUNC(void *) PyMem_RawRealloc(void *ptr, size_t new_size);
PyAPI_FUNC(void) PyMem_RawFree(void *ptr);
#endif

PyAPI_FUNC(void *) PyMem_Malloc(size_t size);
PyAPI_FUNC(void *) PyMem_Calloc(size_t nelem, size_t elsize);
PyAPI_FUNC(void *) PyMem_Realloc(void *ptr, size_t new_size);
PyAPI_FUNC(void) PyMem_Free(void *ptr);

#define PyMem_MALLOC(n)         PyMem_Malloc(n)
#define PyMem_REALLOC(p, n)     PyMem_Realloc(p, n)
#define PyMem_FREE(p)           PyMem_Free(p)


/*
 * Type-oriented memory interface
 * ==============================
 *
 * Allocate memory for n objects of the given type.  Returns a new pointer
 * or NULL if the request was too large or memory allocation failed.  Use
 * these macros rather than doing the multiplication yourself so that proper
 * overflow checking is always done.
 */

#define PyMem_New(type, n) \
  ( ((n) > PY_SSIZE_T_MAX / sizeof(type)) ? NULL : \
        ( (type *) PyMem_Malloc((n) * sizeof(type)) ) )
#define PyMem_NEW(type, n) \
  ( ((n) > PY_SSIZE_T_MAX / sizeof(type)) ? NULL : \
        ( (type *) PyMem_MALLOC((n) * sizeof(type)) ) )

/*
 * The value of (p) is always clobbered by this macro regardless of success.
 * The caller MUST check if (p) is NULL afterwards and deal with the memory
 * error if so.  This means the original value of (p) MUST be saved for the
 * caller's memory error handler to not lose track of it.
 */
#define PyMem_Resize(p, type, n) \
  ( (p) = ((n) > PY_SSIZE_T_MAX / sizeof(type)) ? NULL : \
        (type *) PyMem_Realloc((p), (n) * sizeof(type)) )
#define PyMem_RESIZE(p, type, n) \
  ( (p) = ((n) > PY_SSIZE_T_MAX / sizeof(type)) ? NULL : \
        (type *) PyMem_REALLOC((p), (n) * sizeof(type)) )

/* PyMem{Del,DEL} are left over from ancient days, and shouldn't be used
 * anymore.  They're just confusing aliases for PyMem_{Free,FREE} now.
 */
#define PyMem_Del               PyMem_Free
#define PyMem_DEL               PyMem_FREE


/* From CPython 3.6, with a different goal.  PyTraceMalloc_Track()
 * is equivalent to __pypy__.add_memory_pressure(size); it works with
 * or without the GIL.  PyTraceMalloc_Untrack() is an empty stub.
 * From CPython 3.7 these are public API functions
 *
 *    #if defined(PYPY_TRACEMALLOC) || \
 *         (PY_VERSION_HEX >= 0x03060000 && !defined(Py_LIMITED_API))
 */
#define PYPY_TRACEMALLOC        1

PyAPI_FUNC(int) PyTraceMalloc_Track(
    unsigned int domain,
    uintptr_t ptr,
    size_t size);

PyAPI_FUNC(int) PyTraceMalloc_Untrack(
    unsigned int domain,
    uintptr_t ptr);


#ifdef __cplusplus
}
#endif

#endif /* !Py_PYMEM_H */
