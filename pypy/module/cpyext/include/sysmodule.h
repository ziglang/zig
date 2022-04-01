#ifndef Py_SYSMODULE_H
#define Py_SYSMODULE_H
#ifdef __cplusplus
extern "C" {
#endif

PyAPI_FUNC(void) PySys_WriteStdout(const char *format, ...);
PyAPI_FUNC(void) PySys_WriteStderr(const char *format, ...);

#ifdef __cplusplus
}
#endif
#endif /* !Py_SYSMODULE_H */
