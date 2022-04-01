#ifndef Py_PYCONFIG_H
#define Py_PYCONFIG_H
#ifdef __cplusplus
extern "C" {
#endif

#define HAVE_PROTOTYPES 1
#define STDC_HEADERS 1

#define HAVE_LONG_LONG 1
#define HAVE_STDARG_PROTOTYPES 1
#define PY_FORMAT_LONG_LONG "ll"
#define PY_FORMAT_SIZE_T "z"
#define WITH_DOC_STRINGS
#define HAVE_UNICODE
#define WITHOUT_COMPLEX
#define HAVE_WCHAR_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_STAT_H 1

/* PyPy supposes Py_UNICODE == wchar_t */
#define HAVE_USABLE_WCHAR_T 1
#ifndef _WIN32
#define SIZEOF_WCHAR_T 4
#else
#define SIZEOF_WCHAR_T 2
#endif

#ifndef _WIN32
#define VA_LIST_IS_ARRAY
#ifndef __APPLE__
#define HAVE_CLOCK_GETTIME
#endif
#endif


#ifdef __cplusplus
}
#endif
#endif
