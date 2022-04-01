
#ifndef Py_MODSUPPORT_H
#define Py_MODSUPPORT_H
#ifdef __cplusplus
extern "C" {
#endif

/* Module support interface */

#include <stdarg.h>

/* If PY_SSIZE_T_CLEAN is defined, each functions treats #-specifier
   to mean Py_ssize_t */
#ifdef PY_SSIZE_T_CLEAN
#undef PyArg_Parse
#undef PyArg_ParseTuple
#undef PyArg_ParseTupleAndKeywords
#undef PyArg_VaParse
#undef PyArg_VaParseTupleAndKeywords
#undef Py_BuildValue
#undef Py_VaBuildValue
#define PyArg_Parse                     _PyArg_Parse_SizeT
#define PyArg_ParseTuple                _PyArg_ParseTuple_SizeT
#define PyArg_ParseTupleAndKeywords     _PyArg_ParseTupleAndKeywords_SizeT
#define PyArg_VaParse                   _PyArg_VaParse_SizeT
#define PyArg_VaParseTupleAndKeywords   _PyArg_VaParseTupleAndKeywords_SizeT
#define Py_BuildValue                   _Py_BuildValue_SizeT
#define Py_VaBuildValue                 _Py_VaBuildValue_SizeT
#ifndef Py_LIMITED_API
#define _Py_VaBuildStack                _Py_VaBuildStack_SizeT
#endif
#else
#ifndef Py_LIMITED_API
PyAPI_FUNC(PyObject *) _Py_VaBuildValue_SizeT(const char *, va_list);
PyAPI_FUNC(PyObject **) _Py_VaBuildStack_SizeT(
    PyObject **small_stack,
    Py_ssize_t small_stack_len,
    const char *format,
    va_list va,
    Py_ssize_t *p_nargs);
#endif /* !Py_LIMITED_API */
#endif

/* Due to a glitch in 3.2, the _SizeT versions weren't exported from the DLL. */
#if !defined(PY_SSIZE_T_CLEAN) || !defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03030000
PyAPI_FUNC(int) PyArg_Parse(PyObject *, const char *, ...);
PyAPI_FUNC(int) PyArg_ParseTuple(PyObject *, const char *, ...);
PyAPI_FUNC(int) PyArg_ParseTupleAndKeywords(PyObject *, PyObject *,
                                                  const char *, char **, ...);
PyAPI_FUNC(int) PyArg_VaParse(PyObject *, const char *, va_list);
PyAPI_FUNC(int) PyArg_VaParseTupleAndKeywords(PyObject *, PyObject *,
                                                  const char *, char **, va_list);
#endif
PyAPI_FUNC(int) PyArg_ValidateKeywordArguments(PyObject *);
PyAPI_FUNC(int) PyArg_UnpackTuple(PyObject *, const char *, Py_ssize_t, Py_ssize_t, ...);
PyAPI_FUNC(PyObject *) Py_BuildValue(const char *, ...);
PyAPI_FUNC(PyObject *) _Py_BuildValue_SizeT(const char *, ...);


#ifndef Py_LIMITED_API
PyAPI_FUNC(int) _PyArg_UnpackStack(
    PyObject *const *args,
    Py_ssize_t nargs,
    const char *name,
    Py_ssize_t min,
    Py_ssize_t max,
    ...);

#undef _PyArg_NoKeywords
PyAPI_FUNC(int) _PyArg_NoKeywords(const char *funcname, PyObject *kwargs);
PyAPI_FUNC(int) _PyArg_NoKwnames(const char *funcname, PyObject *kwnames);
PyAPI_FUNC(int) _PyArg_NoPositional(const char *funcname, PyObject *args);
#define _PyArg_NoKeywords(funcname, kwargs) \
    ((kwargs) == NULL || _PyArg_NoKeywords((funcname), (kwargs)))
#define _PyArg_NoKwnames(funcname, kwnames) \
    ((kwnames) == NULL || _PyArg_NoKwnames((funcname), (kwnames)))
#define _PyArg_NoPositional(funcname, args) \
    ((args) == NULL || _PyArg_NoPositional((funcname), (args)))

PyAPI_FUNC(void) _PyArg_BadArgument(const char *, const char *, const char *, PyObject *);
PyAPI_FUNC(int) _PyArg_CheckPositional(const char *, Py_ssize_t,
                                       Py_ssize_t, Py_ssize_t);
#define _PyArg_CheckPositional(funcname, nargs, min, max) \
    (((min) <= (nargs) && (nargs) <= (max)) \
     || _PyArg_CheckPositional((funcname), (nargs), (min), (max)))

#endif

PyAPI_FUNC(PyObject *) Py_VaBuildValue(const char *, va_list);
#ifndef Py_LIMITED_API
PyAPI_FUNC(PyObject **) _Py_VaBuildStack(
    PyObject **small_stack,
    Py_ssize_t small_stack_len,
    const char *format,
    va_list va,
    Py_ssize_t *p_nargs);
#endif

#ifndef Py_LIMITED_API
typedef struct _PyArg_Parser {
    const char *format;
    const char * const *keywords;
    const char *fname;
    const char *custom_msg;
    int pos;            /* number of positional-only arguments */
    int min;            /* minimal number of arguments */
    int max;            /* maximal number of positional arguments */
    PyObject *kwtuple;  /* tuple of keyword parameter names */
    struct _PyArg_Parser *next;
} _PyArg_Parser;
#ifdef PY_SSIZE_T_CLEAN
#define _PyArg_ParseTupleAndKeywordsFast  _PyArg_ParseTupleAndKeywordsFast_SizeT
#define _PyArg_ParseStack  _PyArg_ParseStack_SizeT
#define _PyArg_ParseStackAndKeywords  _PyArg_ParseStackAndKeywords_SizeT
#define _PyArg_VaParseTupleAndKeywordsFast  _PyArg_VaParseTupleAndKeywordsFast_SizeT
#endif
PyAPI_FUNC(int) _PyArg_ParseTupleAndKeywordsFast(PyObject *, PyObject *,
                                                 struct _PyArg_Parser *, ...);
PyAPI_FUNC(int) _PyArg_ParseStack(
    PyObject *const *args,
    Py_ssize_t nargs,
    const char *format,
    ...);
PyAPI_FUNC(int) _PyArg_ParseStackAndKeywords(
    PyObject *const *args,
    Py_ssize_t nargs,
    PyObject *kwnames,
    struct _PyArg_Parser *,
    ...);
PyAPI_FUNC(int) _PyArg_VaParseTupleAndKeywordsFast(PyObject *, PyObject *,
                                                   struct _PyArg_Parser *, va_list);
PyAPI_FUNC(PyObject * const *) _PyArg_UnpackKeywords(
        PyObject *const *args, Py_ssize_t nargs,
        PyObject *kwargs, PyObject *kwnames,
        struct _PyArg_Parser *parser,
        int minpos, int maxpos, int minkw,
        PyObject **buf);
#define _PyArg_UnpackKeywords(args, nargs, kwargs, kwnames, parser, minpos, maxpos, minkw, buf) \
    (((minkw) == 0 && (kwargs) == NULL && (kwnames) == NULL && \
      (minpos) <= (nargs) && (nargs) <= (maxpos) && args != NULL) ? (args) : \
     _PyArg_UnpackKeywords((args), (nargs), (kwargs), (kwnames), (parser), \
                           (minpos), (maxpos), (minkw), (buf)))

void _PyArg_Fini(void);
#endif   /* Py_LIMITED_API */

PyAPI_FUNC(int) PyModule_AddObject(PyObject *, const char *, PyObject *);
PyAPI_FUNC(int) PyModule_AddIntConstant(PyObject *, const char *, long);
PyAPI_FUNC(int) PyModule_AddStringConstant(PyObject *, const char *, const char *);
#if !defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03090000
/* New in 3.9 */
PyAPI_FUNC(int) PyModule_AddType(PyObject *module, PyTypeObject *type);
#endif /* Py_LIMITED_API */

#define PyModule_AddIntMacro(m, c) PyModule_AddIntConstant(m, #c, c)
#define PyModule_AddStringMacro(m, c) PyModule_AddStringConstant(m, #c, c)
#define Py_CLEANUP_SUPPORTED 0x20000

#define PYTHON_API_VERSION 1013
#define PYTHON_API_STRING "1013"
/* The PYTHON_ABI_VERSION is introduced in PEP 384. For the lifetime of
   Python 3, it will stay at the value of 3; changes to the limited API
   must be performed in a strictly backwards-compatible manner. */
#define PYTHON_ABI_VERSION 3
#define PYTHON_ABI_STRING "3"


PyAPI_FUNC(int) _PyArg_Parse_SizeT(PyObject *, const char *, ...);
PyAPI_FUNC(int) _PyArg_ParseTuple_SizeT(PyObject *, const char *, ...);
PyAPI_FUNC(int) _PyArg_VaParse_SizeT(PyObject *, const char *, va_list);

PyAPI_FUNC(int) _PyArg_ParseTupleAndKeywords_SizeT(PyObject *, PyObject *,
				const char *, char **, ...);
PyAPI_FUNC(int) _PyArg_VaParseTupleAndKeywords_SizeT(PyObject *, PyObject *,
				const char *, char **, va_list);
  
PyAPI_FUNC(PyObject *) PyModule_Create2(struct PyModuleDef*,
                                     int apiver);
#ifdef Py_LIMITED_API
#define PyModule_Create(module) \
        PyModule_Create2(module, PYTHON_ABI_VERSION)
#else
#define PyModule_Create(module) \
        PyModule_Create2(module, PYTHON_API_VERSION)
#endif



#ifndef Py_LIMITED_API
PyAPI_DATA(const char *) _Py_PackageContext;
#endif

#ifdef __cplusplus
}
#endif
#endif /* !Py_MODSUPPORT_H */
