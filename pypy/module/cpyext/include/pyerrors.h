
/* Exception interface */

#ifndef Py_PYERRORS_H
#define Py_PYERRORS_H
#ifdef __cplusplus
extern "C" {
#endif

#define PyExceptionClass_Check(x)                                       \
    ((PyType_Check((x)) &&                                              \
      PyType_FastSubclass((PyTypeObject*)(x), Py_TPFLAGS_BASE_EXC_SUBCLASS)))

#define PyExceptionInstance_Check(x)                                    \
    (PyObject_IsSubclass((PyObject *)Py_TYPE(x), PyExc_BaseException))

#define PyExc_EnvironmentError PyExc_OSError
#define PyExc_IOError PyExc_OSError

#ifdef MS_WINDOWS
#define PyExc_WindowsError PyExc_OSError
#endif

PyAPI_FUNC(PyObject *) PyErr_NewException(const char *name, PyObject *base, PyObject *dict);
PyAPI_FUNC(PyObject *) PyErr_NewExceptionWithDoc(const char *name, const char *doc, PyObject *base, PyObject *dict);
PyAPI_FUNC(PyObject *) PyErr_Format(PyObject *exception, const char *format, ...);
PyAPI_FUNC(PyObject *) _PyErr_FormatFromCause(PyObject *exception, const char *format, ...);

/* These APIs aren't really part of the error implementation, but
   often needed to format error messages; the native C lib APIs are
   not available on all platforms, which is why we provide emulations
   for those platforms in Python/mysnprintf.c,
   WARNING:  The return value of snprintf varies across platforms; do
   not rely on any particular behavior; eventually the C99 defn may
   be reliable.
*/
#if defined(MS_WIN32) && !defined(HAVE_SNPRINTF)
# define HAVE_SNPRINTF
# define snprintf _snprintf
# define vsnprintf _vsnprintf
#endif

#include <stdarg.h>
PyAPI_FUNC(int) PyOS_snprintf(char *str, size_t size, const  char  *format, ...);
PyAPI_FUNC(int) PyOS_vsnprintf(char *str, size_t size, const char  *format, va_list va);

typedef struct {
    PyObject_HEAD       /* xxx PyException_HEAD in CPython */
    PyObject *value;
} PyStopIterationObject;

#ifdef __cplusplus
}
#endif
#endif /* !Py_PYERRORS_H */
