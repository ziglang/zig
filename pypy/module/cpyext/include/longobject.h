#ifndef Py_LONGOBJECT_H
#define Py_LONGOBJECT_H

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* why does cpython redefine these, and even supply an implementation in mystrtoul.c?
PyAPI_FUNC(unsigned long) PyOS_strtoul(const char *, char **, int);
PyAPI_FUNC(long) PyOS_strtol(const char *, char **, int);
*/

#define PyOS_strtoul strtoul
#define PyOS_strtol strtoul
#define PyLong_Check(op) \
		 PyType_FastSubclass(Py_TYPE(op), Py_TPFLAGS_LONG_SUBCLASS)
#define PyLong_CheckExact(op) (Py_TYPE(op) == &PyLong_Type)

#define PyLong_AS_LONG(op) PyLong_AsLong(op)

#define _PyLong_AsByteArray(v, bytes, n, little_endian, is_signed)   \
    _PyLong_AsByteArrayO((PyObject *)(v), bytes, n, little_endian, is_signed)

#ifdef __cplusplus
}
#endif
#endif /* !Py_LONGOBJECT_H */
