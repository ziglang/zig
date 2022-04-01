#ifndef Py_PYLIFECYCLE_H
#define Py_PYLIFECYCLE_H
#ifdef __cplusplus
extern "C" {
#endif


/* Restore signals that the interpreter has called SIG_IGN on to SIG_DFL. */
#ifndef Py_LIMITED_API
PyAPI_FUNC(void) _Py_RestoreSignals(void);
#endif

/* In Python <= 3.6 there is a variable _Py_Finalizing of type
   'PyThreadState *'.  Emulate it with a macro. */
#define _Py_Finalizing  \
    (_Py_IsFinalizing() ? _PyThreadState_UncheckedGet() : NULL)


#ifdef __cplusplus
}
#endif
#endif /* !Py_PYLIFECYCLE_H */
