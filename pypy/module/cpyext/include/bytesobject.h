/* A copy of pypy2's PyStringObject */

#ifndef Py_BYTESOBJECT_H
#define Py_BYTESOBJECT_H
#ifdef __cplusplus
extern "C" {
#endif

#include <stdarg.h>

#define PyBytes_GET_SIZE(op) PyBytes_Size(op)

/*
Type PyStringObject represents a character string.  An extra zero byte is
reserved at the end to ensure it is zero-terminated, but a size is
present so strings with null bytes in them can be represented.  This
is an immutable object type.

There are functions to create new string objects, to test
an object for string-ness, and to get the
string value.  The latter function returns a null pointer
if the object is not of the proper type.
There is a variant that takes an explicit size as well as a
variant that assumes a zero-terminated string.  Note that none of the
functions should be applied to nil objects.
*/

/* Caching the hash (ob_shash) saves recalculation of a string's hash value.
   Interning strings (ob_sstate) tries to ensure that only one string
   object with a given value exists, so equality tests can be one pointer
   comparison.  This is generally restricted to strings that "look like"
   Python identifiers, although the intern() builtin can be used to force
   interning of any string.
   Together, these sped cpython up by up to 20%, and since they are part of the
   "public" interface PyPy must reimpliment them. */

typedef struct {
    PyObject_VAR_HEAD
    Py_hash_t ob_shash;
    int ob_sstate;
    char ob_sval[1]; 

    /* Invariants 
     *     ob_sval contains space for 'ob_size+1' elements.
     *     ob_sval[ob_size] == 0.
     *     ob_shash is the hash of the string or -1 if not computed yet.
     *     ob_sstate != 0 iff the string object is in stringobject.c's
     *       'interned' dictionary; in this case the two references
     *       from 'interned' to this object are *not counted* in ob_refcnt.
     */
} PyBytesObject;

#define SSTATE_NOT_INTERNED 0
#define SSTATE_INTERNED_MORTAL 1
#define SSTATE_INTERNED_IMMORTAL 2
#define PyString_CHECK_INTERNED(op) (((PyStringObject *)(op))->ob_sstate)

#define PyBytes_Check(op) \
                 PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_BYTES_SUBCLASS)
#define PyBytes_CheckExact(op) (Py_TYPE(op) == &PyBytes_Type)

PyAPI_FUNC(PyObject *) PyBytes_FromFormatV(const char*, va_list);
PyAPI_FUNC(PyObject *) PyBytes_FromFormat(const char*, ...);

#ifdef __cplusplus
}
#endif
#endif
