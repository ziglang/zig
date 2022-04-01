#ifndef Py_FRAMEOBJECT_H
#define Py_FRAMEOBJECT_H
#ifdef __cplusplus
extern "C" {
#endif

typedef struct _frame {
    PyObject_HEAD
    struct _frame *f_back;      /* previous frame, or NULL */
    PyCodeObject *f_code;
    PyObject *f_globals;
    PyObject *f_locals;
    int f_lineno;
} PyFrameObject;

#ifdef __cplusplus
}
#endif
#endif /* !Py_FRAMEOBJECT_H */
