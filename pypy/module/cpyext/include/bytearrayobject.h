/* ByteArray object interface */

#ifndef Py_BYTEARRAYOBJECT_H
#define Py_BYTEARRAYOBJECT_H
#ifdef __cplusplus
extern "C" {
#endif

#include <stdarg.h>

/* Type PyByteArrayObject represents a mutable array of bytes.
 * The Python API is that of a sequence;
 * the bytes are mapped to ints in [0, 256).
 * Bytes are not characters; they may be used to encode characters.
 * The only way to go between bytes and str/unicode is via encoding
 * and decoding.
 * While CPython exposes interfaces to this object, pypy does not
 */

#define PyByteArray_GET_SIZE(op) PyByteArray_Size((PyObject*)(op))
#define PyByteArray_AS_STRING(op) PyByteArray_AsString((PyObject*)(op))

/* Object layout */
typedef struct {
    PyObject_VAR_HEAD
#if 0
    int ob_exports; /* how many buffer exports */
    Py_ssize_t ob_alloc; /* How many bytes allocated */
    char *ob_bytes;
#endif
} PyByteArrayObject;

#ifdef __cplusplus
}
#endif
#endif /* !Py_BYTEARRAYOBJECT_H */
