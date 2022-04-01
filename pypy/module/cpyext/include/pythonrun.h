/* Interfaces to parse and execute pieces of python code */

#ifndef Py_PYTHONRUN_H
#define Py_PYTHONRUN_H
#ifdef __cplusplus
extern "C" {
#endif

PyAPI_FUNC(void) Py_FatalError(const char *msg);

/* taken from Python-3.2.3/Include/pydebug.h */
/* Note: they are always 0 for now, expect Py_DebugFlag which is always 1 */
PyAPI_DATA(int) Py_DebugFlag;
PyAPI_DATA(int) Py_VerboseFlag;
PyAPI_DATA(int) Py_QuietFlag;
PyAPI_DATA(int) Py_InteractiveFlag;
PyAPI_DATA(int) Py_InspectFlag;
PyAPI_DATA(int) Py_OptimizeFlag;
PyAPI_DATA(int) Py_NoSiteFlag;
PyAPI_DATA(int) Py_BytesWarningFlag;
PyAPI_DATA(int) Py_FrozenFlag; /* set when the python is "frozen" */
PyAPI_DATA(int) Py_IgnoreEnvironmentFlag;
PyAPI_DATA(int) Py_DontWriteBytecodeFlag;
PyAPI_DATA(int) Py_NoUserSiteDirectory;
PyAPI_DATA(int) Py_UnbufferedStdioFlag;
PyAPI_DATA(int) Py_HashRandomizationFlag;
PyAPI_DATA(int) Py_IsolatedFlag;

#ifdef _WIN32
PyAPI_DATA(int) Py_LegacyWindowsStdioFlag;
#endif

#define Py_GETENV(s) (Py_IgnoreEnvironmentFlag ? NULL : getenv(s))


typedef struct {
    int cf_flags;  /* bitmask of CO_xxx flags relevant to future */
    int cf_feature_version;  /* minor Python version (PyCF_ONLY_AST) */
} PyCompilerFlags;

#define _PyCompilerFlags_INIT \
    (PyCompilerFlags){.cf_flags = 0, .cf_feature_version = PY_MINOR_VERSION}

#define PyCF_MASK (CO_FUTURE_DIVISION | CO_FUTURE_ABSOLUTE_IMPORT | \
                   CO_FUTURE_WITH_STATEMENT | CO_FUTURE_PRINT_FUNCTION | \
                   CO_FUTURE_UNICODE_LITERALS)
#define PyCF_MASK_OBSOLETE (CO_NESTED)
#define PyCF_SOURCE_IS_UTF8  0x0100
#define PyCF_DONT_IMPLY_DEDENT 0x0200
#define PyCF_ONLY_AST 0x0400

#define Py_CompileString(str, filename, start) Py_CompileStringFlags(str, filename, start, NULL)

/* Stuff with no proper home (yet) */
PyAPI_DATA(int) (*PyOS_InputHook)(void);
typedef int (*_pypy_pyos_inputhook)(void);
PyAPI_FUNC(_pypy_pyos_inputhook) _PyPy_get_PyOS_InputHook(void);

#ifdef __cplusplus
}
#endif
#endif /* !Py_PYTHONRUN_H */
