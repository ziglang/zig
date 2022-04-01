#ifndef Py_PYTHON_H
#define Py_PYTHON_H

#include "patchlevel.h"
#include <pyconfig.h>

/* Compat stuff */
#ifdef __GNUC__
#define _GNU_SOURCE 1
#endif
#ifndef _WIN32
# include <stddef.h>
# include <limits.h>
# include <math.h>
# include <errno.h>
# include <unistd.h>
#else
# ifdef _MSC_VER
#  include <crtdefs.h>
# endif
# ifdef __MINGW32__
#  include <limits.h>
# endif
# include <io.h>
# include <sys/types.h>   /* for 'off_t' */
#endif

/* Deprecated DL_IMPORT and DL_EXPORT macros */
#ifdef _WIN32
# if defined(Py_BUILD_CORE)
#  define DL_IMPORT(RTYPE) __declspec(dllexport) RTYPE
#  define DL_EXPORT(RTYPE) __declspec(dllexport) RTYPE
# else
#  define DL_IMPORT(RTYPE) __declspec(dllimport) RTYPE
#  define DL_EXPORT(RTYPE) __declspec(dllexport) RTYPE
# endif
#endif
#ifndef DL_EXPORT
#       define DL_EXPORT(RTYPE) PyAPI_FUNC(RTYPE)
#endif
#ifndef DL_IMPORT
#       define DL_IMPORT(RTYPE) RTYPE
#endif
#include <stdlib.h>

#define Py_SAFE_DOWNCAST(VALUE, WIDE, NARROW) (NARROW)(VALUE)

#define Py_USING_UNICODE

#define statichere static

#define Py_MEMCPY memcpy
#include "pyport.h"

#include "pypy_macros.h"
#include "pymacro.h"

#include "object.h"
#include "typeslots.h"
#include "abstract.h"
#include "pymath.h"
#include "pytime.h"
#include "warnings.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <locale.h>
#include <ctype.h>

#include "pyhash.h"
#include "boolobject.h"
#include "floatobject.h"
#include "complexobject.h"
#include "methodobject.h"
#include "funcobject.h"
#include "code.h"

#include "moduleobject.h"
#include "modsupport.h"
#include "pythonrun.h"
#include "pyerrors.h"
#include "sysmodule.h"
#include "bytearrayobject.h"
#include "descrobject.h"
#include "tupleobject.h"
#include "dictobject.h"
#include "longobject.h"
#include "setobject.h"
#include "listobject.h"
#include "longobject.h"
#include "unicodeobject.h"
#include "compile.h"
#include "frameobject.h"
#include "memoryobject.h"
#include "eval.h"
#include "pymem.h"
#include "pycapsule.h"
#include "bytesobject.h"
#include "sliceobject.h"
#include "genobject.h"
#include "datetime.h"
#include "structseq.h"
#include "pystate.h"
#include "fileobject.h"
#include "pysignals.h"
#include "pythread.h"
#include "traceback.h"
#include "pylifecycle.h"
#include "genericaliasobject.h"

/* Missing definitions */
#include "missing.h"

/* The declarations of most API functions are generated in a separate file */
/* Don't include them while building PyPy, RPython also generated signatures
 * which are similar but not identical. */
#ifndef PYPY_STANDALONE
#ifdef __cplusplus
extern "C" {
#endif
  #include "pypy_decl.h"
#ifdef __cplusplus
}
#endif
#endif  /* PYPY_STANDALONE */

/* Define macros for inline documentation. */
#define PyDoc_VAR(name) static char name[]
#define PyDoc_STRVAR(name,str) PyDoc_VAR(name) = PyDoc_STR(str)
#ifdef WITH_DOC_STRINGS
#define PyDoc_STR(str) str
#else
#define PyDoc_STR(str) ""
#endif

/* PyPy does not implement --with-fpectl */
#define PyFPE_START_PROTECT(err_string, leave_stmt)
#define PyFPE_END_PROTECT(v)

#include "pystrtod.h"

#endif
