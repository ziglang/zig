
/* signal interface */

#ifndef Py_PYSIGNALS_H
#define Py_PYSIGNALS_H
#ifdef __cplusplus
extern "C" {
#endif

typedef void (*PyOS_sighandler_t)(int);

PyAPI_FUNC(PyOS_sighandler_t) PyOS_setsig(int sig, PyOS_sighandler_t handler);
PyAPI_FUNC(PyOS_sighandler_t) PyOS_getsig(int sig);


#ifdef __cplusplus
}
#endif
#endif /* !Py_PYSIGNALS_H */
