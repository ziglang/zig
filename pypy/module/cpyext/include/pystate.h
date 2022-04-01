/* Thread and interpreter state structures and their interfaces */


#ifndef Py_PYSTATE_H
#define Py_PYSTATE_H
#ifdef __cplusplus
extern "C" {
#endif

/* This limitation is for performance and simplicity. If needed it can be
removed (with effort). */
#define MAX_CO_EXTRA_USERS 255

/* Forward declarations for PyFrameObject, PyThreadState
   and PyInterpreterState */
struct _ts;
struct _is;

typedef struct _is {
    struct _is *next;
    PyObject * modules_by_index;
} PyInterpreterState;

typedef struct _ts {
    PyInterpreterState *interp;
    PyObject *dict;  /* Stores per-thread state */
} PyThreadState;

#define Py_BEGIN_ALLOW_THREADS { \
			PyThreadState *_save; \
			_save = PyEval_SaveThread();
#define Py_BLOCK_THREADS	PyEval_RestoreThread(_save);
#define Py_UNBLOCK_THREADS	_save = PyEval_SaveThread();
#define Py_END_ALLOW_THREADS	PyEval_RestoreThread(_save); \
		 }

enum {PyGILState_LOCKED, PyGILState_UNLOCKED};
typedef int PyGILState_STATE;

#define PyThreadState_GET() PyThreadState_Get()
PyAPI_FUNC(PyObject*) PyState_FindModule(struct PyModuleDef*);

#ifdef __cplusplus
}
#endif
#endif /* !Py_PYSTATE_H */
