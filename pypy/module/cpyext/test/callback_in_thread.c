/* A test module that spawns a thread and run a function there */

#include <Python.h>
#include <pthread.h>

struct thread_data {
    PyInterpreterState *interp;
    PyObject *callback;
};

static void *thread_function(void* ptr) {
    struct thread_data *data = (struct thread_data *)ptr;
    PyInterpreterState *interp = data->interp;
    /* Assuming you have access to an interpreter object, the typical
     * idiom for calling into Python from a C thread is: */

    PyThreadState *tstate;
    PyObject *result;

    /* interp is your reference to an interpreter object. */
    tstate = PyThreadState_New(interp);
    PyEval_AcquireThread(tstate);

    /* Perform Python actions here.  */
    result = PyObject_CallFunction(data->callback,
				   "l", (long)pthread_self());
    if (!result)
	PyErr_Print();
    else
	Py_DECREF(result);

    Py_DECREF(data->callback);

    /* XXX Python examples don't mention it, but docs say that
     * PyThreadState_Delete requires it. */
    PyThreadState_Clear(tstate);

    /* Release the thread. No Python API allowed beyond this point. */
    PyEval_ReleaseThread(tstate);

    /* You can either delete the thread state, or save it
       until you need it the next time. */
    PyThreadState_Delete(tstate);

    free(data);
    return NULL;
}

static PyObject *
run_callback(PyObject *self, PyObject *callback)
{
    pthread_t thread;
    struct thread_data *data = malloc(sizeof(struct thread_data));
    Py_INCREF(callback);
    data->interp = PyThreadState_Get()->interp;
    data->callback = callback;
    pthread_create(&thread, NULL, thread_function, (void*)data);
    Py_RETURN_NONE;
}


static PyMethodDef module_functions[] = {
    {"callInThread", (PyCFunction)run_callback, METH_O, NULL},
    {NULL,        NULL}    /* Sentinel */
};

#ifdef __GNUC__
extern __attribute__((visibility("default")))
#else
extern __declspec(dllexport)
#endif

PyMODINIT_FUNC
initcallback_in_thread(void)
{
    PyObject *m;
    m = Py_InitModule("callback_in_thread", module_functions);
    if (m == NULL)
        return;
    PyEval_InitThreads();
}

/* 
cc -g -O0 -c callback_in_thread.c -I /usr/include/python2.6 -fPIC && ld -g -O0 callback_in_thread.o --shared -o callback_in_thread.so && gdb --args ~/python/cpython2.7/python -c "from __future__ import print_function; import threading, time; from callback_in_thread import callInThread; callInThread(print); time.sleep(1)"


cc -g -O0 -c callback_in_thread.c -I ~/pypy/pypy/include -fPIC && ld -g -O0 callback_in_thread.o --shared -o callback_in_thread.pypy-19.so && gdb --args ~/pypy/pypy/pypy/pypy-c -c "from __future__ import print_function; import threading, time; from callback_in_thread import callInThread; callInThread(print); time.sleep(1)"

 */
