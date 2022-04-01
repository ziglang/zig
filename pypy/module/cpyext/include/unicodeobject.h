#ifndef Py_UNICODEOBJECT_H
#define Py_UNICODEOBJECT_H

#ifndef SIZEOF_WCHAR_T
#error Must define SIZEOF_WCHAR_T
#endif

#define Py_UNICODE_SIZE SIZEOF_WCHAR_T

/* If wchar_t can be used for UCS-4 storage, set Py_UNICODE_WIDE.
   Otherwise, Unicode strings are stored as UCS-2 (with limited support
   for UTF-16) */

#if Py_UNICODE_SIZE >= 4
#define Py_UNICODE_WIDE
#endif

/* Set these flags if the platform has "wchar.h" and the
   wchar_t type is a 16-bit unsigned type */
/* #define HAVE_WCHAR_H */
/* #define HAVE_USABLE_WCHAR_T */

#ifdef HAVE_WCHAR_H
/* Work around a cosmetic bug in BSDI 4.x wchar.h; thanks to Thomas Wouters */
# ifdef _HAVE_BSDI
#  include <time.h>
# endif
#  include <wchar.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#include "cpyext_unicodeobject.h"

#define PyUnicode_Check(op) \
    PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_UNICODE_SUBCLASS)
#define PyUnicode_CheckExact(op) (Py_TYPE(op) == &PyUnicode_Type)




/* Fast access macros */
#ifndef Py_LIMITED_API

#define PyUnicode_WSTR_LENGTH(op) \
    (PyUnicode_IS_COMPACT_ASCII(op) ?                  \
     ((PyASCIIObject*)op)->length :                    \
     ((PyCompactUnicodeObject*)op)->wstr_length)

/* Returns the deprecated Py_UNICODE representation's size in code units
   (this includes surrogate pairs as 2 units).
   If the Py_UNICODE representation is not available, it will be computed
   on request.  Use PyUnicode_GET_LENGTH() for the length in code points. */

#define PyUnicode_GET_SIZE(op)                       \
    (assert(PyUnicode_Check(op)),                    \
     (((PyASCIIObject *)(op))->wstr) ?               \
      PyUnicode_WSTR_LENGTH(op) :                    \
      ((void)PyUnicode_AsUnicode((PyObject *)(op)),  \
       assert(((PyASCIIObject *)(op))->wstr),        \
       PyUnicode_WSTR_LENGTH(op)))

#define PyUnicode_GET_DATA_SIZE(op) \
    (PyUnicode_GET_SIZE(op) * Py_UNICODE_SIZE)

/* Alias for PyUnicode_AsUnicode().  This will create a wchar_t/Py_UNICODE
   representation on demand.  Using this macro is very inefficient now,
   try to port your code to use the new PyUnicode_*BYTE_DATA() macros or
   use PyUnicode_WRITE() and PyUnicode_READ(). */

#define PyUnicode_AS_UNICODE(op) \
     ((((PyASCIIObject *)(op))->wstr) ? (((PyASCIIObject *)(op))->wstr) : \
      PyUnicode_AsUnicode((PyObject *)(op)))

#define PyUnicode_AS_DATA(op) \
    ((const char *)(PyUnicode_AS_UNICODE(op)))


/* --- Flexible String Representation Helper Macros (PEP 393) -------------- */

/* Values for PyASCIIObject.state: */

/* Interning state. */
#define SSTATE_NOT_INTERNED 0
#define SSTATE_INTERNED_MORTAL 1
#define SSTATE_INTERNED_IMMORTAL 2

/* Return true if the string contains only ASCII characters, or 0 if not. The
   string may be compact (PyUnicode_IS_COMPACT_ASCII) or not, but must be
   ready. */
#define PyUnicode_IS_ASCII(op)                   \
    (assert(PyUnicode_Check(op)),                \
     assert(PyUnicode_IS_READY(op)),             \
     ((PyASCIIObject*)op)->state.ascii)

/* Return true if the string is compact or 0 if not.
   No type checks or Ready calls are performed. */
#define PyUnicode_IS_COMPACT(op) \
    (((PyASCIIObject*)(op))->state.compact)

/* Return true if the string is a compact ASCII string (use PyASCIIObject
   structure), or 0 if not.  No type checks or Ready calls are performed. */
#define PyUnicode_IS_COMPACT_ASCII(op)                 \
    (((PyASCIIObject*)op)->state.ascii && PyUnicode_IS_COMPACT(op))

enum PyUnicode_Kind {
/* String contains only wstr byte characters.  This is only possible
   when the string was created with a legacy API and _PyUnicode_Ready()
   has not been called yet.  */
    PyUnicode_WCHAR_KIND = 0,
/* Return values of the PyUnicode_KIND() macro: */
    PyUnicode_1BYTE_KIND = 1,
    PyUnicode_2BYTE_KIND = 2,
    PyUnicode_4BYTE_KIND = 4
};

/* Return pointers to the canonical representation cast to unsigned char,
   Py_UCS2, or Py_UCS4 for direct character access.
   No checks are performed, use PyUnicode_KIND() before to ensure
   these will work correctly. */

#define PyUnicode_1BYTE_DATA(op) ((Py_UCS1*)PyUnicode_DATA(op))
#define PyUnicode_2BYTE_DATA(op) ((Py_UCS2*)PyUnicode_DATA(op))
#define PyUnicode_4BYTE_DATA(op) ((Py_UCS4*)PyUnicode_DATA(op))

/* Return one of the PyUnicode_*_KIND values defined above. */
#define PyUnicode_KIND(op) \
    (assert(PyUnicode_Check(op)), \
     assert(PyUnicode_IS_READY(op)),            \
     ((PyASCIIObject *)(op))->state.kind)

/* Return a void pointer to the raw unicode buffer. */
#define _PyUnicode_COMPACT_DATA(op)                     \
    (PyUnicode_IS_ASCII(op) ?                   \
     ((void*)((PyASCIIObject*)(op) + 1)) :              \
     ((void*)((PyCompactUnicodeObject*)(op) + 1)))

#define _PyUnicode_NONCOMPACT_DATA(op)                  \
    (assert(((PyUnicodeObject*)(op))->data),        \
     ((((PyUnicodeObject *)(op))->data)))

#define PyUnicode_DATA(op) \
    (assert(PyUnicode_Check(op)), \
     PyUnicode_IS_COMPACT(op) ? _PyUnicode_COMPACT_DATA(op) :   \
     _PyUnicode_NONCOMPACT_DATA(op))

/* In the access macros below, "kind" may be evaluated more than once.
   All other macro parameters are evaluated exactly once, so it is safe
   to put side effects into them (such as increasing the index). */

/* Write into the canonical representation, this macro does not do any sanity
   checks and is intended for usage in loops.  The caller should cache the
   kind and data pointers obtained from other macro calls.
   index is the index in the string (starts at 0) and value is the new
   code point value which should be written to that location. */
#define PyUnicode_WRITE(kind, data, index, value) \
    do { \
        switch ((kind)) { \
        case PyUnicode_1BYTE_KIND: { \
            ((Py_UCS1 *)(data))[(index)] = (Py_UCS1)(value); \
            break; \
        } \
        case PyUnicode_2BYTE_KIND: { \
            ((Py_UCS2 *)(data))[(index)] = (Py_UCS2)(value); \
            break; \
        } \
        default: { \
            assert((kind) == PyUnicode_4BYTE_KIND); \
            ((Py_UCS4 *)(data))[(index)] = (Py_UCS4)(value); \
        } \
        } \
    } while (0)

/* Read a code point from the string's canonical representation.  No checks
   or ready calls are performed. */
#define PyUnicode_READ(kind, data, index) \
    ((Py_UCS4) \
    ((kind) == PyUnicode_1BYTE_KIND ? \
        ((const Py_UCS1 *)(data))[(index)] : \
        ((kind) == PyUnicode_2BYTE_KIND ? \
            ((const Py_UCS2 *)(data))[(index)] : \
            ((const Py_UCS4 *)(data))[(index)] \
        ) \
    ))

/* PyUnicode_READ_CHAR() is less efficient than PyUnicode_READ() because it
   calls PyUnicode_KIND() and might call it twice.  For single reads, use
   PyUnicode_READ_CHAR, for multiple consecutive reads callers should
   cache kind and use PyUnicode_READ instead. */
#define PyUnicode_READ_CHAR(unicode, index) \
    (assert(PyUnicode_Check(unicode)),          \
     assert(PyUnicode_IS_READY(unicode)),       \
     (Py_UCS4)                                  \
        (PyUnicode_KIND((unicode)) == PyUnicode_1BYTE_KIND ? \
            ((const Py_UCS1 *)(PyUnicode_DATA((unicode))))[(index)] : \
            (PyUnicode_KIND((unicode)) == PyUnicode_2BYTE_KIND ? \
                ((const Py_UCS2 *)(PyUnicode_DATA((unicode))))[(index)] : \
                ((const Py_UCS4 *)(PyUnicode_DATA((unicode))))[(index)] \
            ) \
        ))

/* Returns the length of the unicode string. The caller has to make sure that
   the string has it's canonical representation set before calling
   this macro.  Call PyUnicode_(FAST_)Ready to ensure that. */
#define PyUnicode_GET_LENGTH(op)                \
    (assert(PyUnicode_Check(op)),               \
     assert(PyUnicode_IS_READY(op)),            \
     ((PyASCIIObject *)(op))->length)


/* Fast check to determine whether an object is ready. Equivalent to
   PyUnicode_IS_COMPACT(op) || ((PyUnicodeObject*)(op))->data.any) */

#define PyUnicode_IS_READY(op) (((PyASCIIObject*)op)->state.ready)

/* PyUnicode_READY() does less work than _PyUnicode_Ready() in the best
   case.  If the canonical representation is not yet set, it will still call
   _PyUnicode_Ready().
   Returns 0 on success and -1 on errors. */
#define PyUnicode_READY(op)                        \
    (assert(PyUnicode_Check(op)),                       \
     (PyUnicode_IS_READY(op) ?                          \
      0 : _PyUnicode_Ready((PyObject *)(op))))

/* Return a maximum character value which is suitable for creating another
   string based on op.  This is always an approximation but more efficient
   than iterating over the string. */
#define PyUnicode_MAX_CHAR_VALUE(op) \
    (assert(PyUnicode_IS_READY(op)),                                    \
     (PyUnicode_IS_ASCII(op) ?                                          \
      (0x7f) :                                                          \
      (PyUnicode_KIND(op) == PyUnicode_1BYTE_KIND ?                     \
       (0xffU) :                                                        \
       (PyUnicode_KIND(op) == PyUnicode_2BYTE_KIND ?                    \
        (0xffffU) :                                                     \
        (0x10ffffU)))))

#endif

/* --- Constants ---------------------------------------------------------- */

/* This Unicode character will be used as replacement character during
   decoding if the errors argument is set to "replace". Note: the
   Unicode character U+FFFD is the official REPLACEMENT CHARACTER in
   Unicode 3.0. */

#define Py_UNICODE_REPLACEMENT_CHARACTER ((Py_UCS4) 0xFFFD)

/* === Public API ========================================================= */

/* Get the length of the Unicode object. */

PyAPI_FUNC(Py_ssize_t) PyUnicode_GetLength(
    PyObject *unicode
);

/* Get the number of Py_UNICODE units in the
   string representation. */

PyAPI_FUNC(Py_ssize_t) PyUnicode_GetSize(
    PyObject *unicode           /* Unicode object */
    );

PyAPI_FUNC(PyObject *) PyUnicode_FromFormatV(
    const char *format,   /* ASCII-encoded string  */
    va_list vargs
    );
PyAPI_FUNC(PyObject *) PyUnicode_FromFormat(
    const char *format,   /* ASCII-encoded string  */
    ...
    );

/* Use only if you know it's a string */
#define PyUnicode_CHECK_INTERNED(op) \
    (((PyASCIIObject *)(op))->state.interned)

/* --- wchar_t support for platforms which support it --------------------- */

#ifdef HAVE_WCHAR_H

/* Create a Unicode Object from the wchar_t buffer w of the given
   size.

   The buffer is copied into the new object. */

PyAPI_FUNC(PyObject*) PyUnicode_FromWideChar(
    const wchar_t *w,           /* wchar_t buffer */
    Py_ssize_t size             /* size of buffer */
    );

/* Convert the Unicode object to a wide character string. The output string
   always ends with a nul character. If size is not NULL, write the number of
   wide characters (excluding the null character) into *size.

   Returns a buffer allocated by PyMem_Malloc() (use PyMem_Free() to free it)
   on success. On error, returns NULL, *size is undefined and raises a
   MemoryError. */

PyAPI_FUNC(wchar_t*) PyUnicode_AsWideCharString(
    PyObject *unicode,          /* Unicode object */
    Py_ssize_t *size            /* number of characters of the result */
    );

#endif

/* === Builtin Codecs =====================================================

   Many of these APIs take two arguments encoding and errors. These
   parameters encoding and errors have the same semantics as the ones
   of the builtin str() API.

   Setting encoding to NULL causes the default encoding (UTF-8) to be used.

   Error handling is set by errors which may also be set to NULL
   meaning to use the default handling defined for the codec. Default
   error handling for all builtin codecs is "strict" (ValueErrors are
   raised).

   The codecs all use a similar interface. Only deviation from the
   generic ones are documented.

*/

/* --- Manage the default encoding ---------------------------------------- */

/* Returns a pointer to the default encoding (UTF-8) of the
   Unicode object unicode and the size of the encoded representation
   in bytes stored in *size.

   In case of an error, no *size is set.

   This function caches the UTF-8 encoded string in the unicodeobject
   and subsequent calls will return the same string.  The memory is released
   when the unicodeobject is deallocated.

   _PyUnicode_AsStringAndSize is a #define for PyUnicode_AsUTF8AndSize to
   support the previous internal function with the same behaviour.

   *** This API is for interpreter INTERNAL USE ONLY and will likely
   *** be removed or changed in the future.

   *** If you need to access the Unicode object as UTF-8 bytes string,
   *** please use PyUnicode_AsUTF8String() instead.
*/

#ifndef Py_LIMITED_API
PyAPI_FUNC(char *) PyUnicode_AsUTF8AndSize(
    PyObject *unicode,
    Py_ssize_t *size);
#define _PyUnicode_AsStringAndSize PyUnicode_AsUTF8AndSize
#endif

/* Returns a pointer to the default encoding (UTF-8) of the
   Unicode object unicode.

   Like PyUnicode_AsUTF8AndSize(), this also caches the UTF-8 representation
   in the unicodeobject.

   _PyUnicode_AsString is a #define for PyUnicode_AsUTF8 to
   support the previous internal function with the same behaviour.

   Use of this API is DEPRECATED since no size information can be
   extracted from the returned data.

   *** This API is for interpreter INTERNAL USE ONLY and will likely
   *** be removed or changed for Python 3.1.

   *** If you need to access the Unicode object as UTF-8 bytes string,
   *** please use PyUnicode_AsUTF8String() instead.

*/

#ifndef Py_LIMITED_API
#define _PyUnicode_AsString PyUnicode_AsUTF8
#endif

Py_LOCAL_INLINE(size_t) Py_UNICODE_strlen(const Py_UNICODE *u)
{
    size_t res = 0;
    while(*u++)
        res++;
    return res;
}

Py_LOCAL_INLINE(int)
Py_UNICODE_strcmp(const Py_UNICODE *s1, const Py_UNICODE *s2)
{
    while (*s1 && *s2 && *s1 == *s2)
        s1++, s2++;
    if (*s1 && *s2)
        return (*s1 < *s2) ? -1 : +1;
    if (*s1)
        return 1;
    if (*s2)
        return -1;
    return 0;
}

#ifdef __cplusplus
}
#endif
#endif /* !Py_UNICODEOBJECT_H */
