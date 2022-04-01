#ifndef Py_WARNINGS_H
#define Py_WARNINGS_H
#ifdef __cplusplus
extern "C" {
#endif

#define PyErr_WarnPy3k(msg, stacklevel) 0

PyAPI_FUNC(int) PyErr_WarnFormat(PyObject *category, Py_ssize_t stack_level,
                                 const char *format, ...);

#ifdef __cplusplus
}
#endif
#endif /* !Py_WARNINGS_H */
