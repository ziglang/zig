
/* set object interface */

#ifndef Py_SETOBJECT_H
#define Py_SETOBJECT_H
#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    PyObject_HEAD
    PyObject *_tmplist; /* a private place to put values during _PySet_Next */
} PySetObject;

#ifdef __cplusplus
}
#endif
#endif /* !Py_SETOBJECT_H */

