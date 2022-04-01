/**
 * This file is the CPython module _vmprof. It does not share code
 * with PyPy. PyPy's _vmprof module is included in the main repo.
 */
#define _GNU_SOURCE 1

#include <Python.h>
#include <frameobject.h>
#include <signal.h>

#include "_vmprof.h"
#include "vmprof_common.h"

static destructor Original_code_dealloc = 0;
static PyObject* (*_default_eval_loop)(PyFrameObject *, int) = 0;

#if VMPROF_UNIX
#include "trampoline.h"
#include "machine.h"
#include "symboltable.h"
#include "vmprof_unix.h"
#else
#include "vmprof_win.h"
#endif
#include "vmp_stack.h"

#ifdef VMPROF_UNIX
#ifdef __clang__
__attribute__((optnone))
#elif defined(__GNUC__)
__attribute__((optimize("O1")))
#endif
PY_EVAL_RETURN_T * vmprof_eval(PY_STACK_FRAME_T *f, int throwflag)
{
#ifdef X86_64
    register PY_STACK_FRAME_T * callee_saved asm("rbx");
#elif defined(X86_32)
    register PY_STACK_FRAME_T * callee_saved asm("edi");
#elif defined(__arm__)
    register PY_STACK_FRAME_T * callee_saved asm("r4");
#elif defined(__aarch64__)
    register PY_STACK_FRAME_T * callee_saved asm("x19");
#elif defined(__powerpc64__)
    register PY_STACK_FRAME_T * callee_saved asm("r3");
#else
#    error "platform not supported"
#endif

    asm volatile(
#ifdef X86_64
        "movq %1, %0\t\n"
#elif defined(X86_32)
        "mov %1, %0\t\n"
#elif defined(__arm__) || defined(__aarch64__)
	"mov %1, %0\t\n"
#elif defined(__powerpc64__)
	"addi %1, %0, 0\t\n"
#else
#    error "platform not supported"
#endif
        : "=r" (callee_saved)
        : "r" (f) );
    return _default_eval_loop(f, throwflag);
}
#endif

static int emit_code_object(PyCodeObject *co)
{
    char buf[MAX_FUNC_NAME + 1];
    char *co_name, *co_filename;
    int co_firstlineno;
    int sz;
#if PY_MAJOR_VERSION >= 3
    co_name = PyUnicode_AsUTF8(co->co_name);
    if (co_name == NULL)
        return -1;
    co_filename = PyUnicode_AsUTF8(co->co_filename);
    if (co_filename == NULL)
        return -1;
#else
    co_name = PyString_AS_STRING(co->co_name);
    co_filename = PyString_AS_STRING(co->co_filename);
#endif
    co_firstlineno = co->co_firstlineno;

    sz = snprintf(buf, MAX_FUNC_NAME / 2, "py:%s", co_name);
    if (sz < 0) sz = 0;
    if (sz > MAX_FUNC_NAME / 2) sz = MAX_FUNC_NAME / 2;
    snprintf(buf + sz, MAX_FUNC_NAME / 2, ":%d:%s", co_firstlineno,
             co_filename);
    return vmprof_register_virtual_function(buf, CODE_ADDR_TO_UID(co), 500000);
}

static int _look_for_code_object(PyObject *o, void * param)
{
    int i;
    PyObject * all_codes, * seen_codes;

    all_codes = (PyObject*)((void**)param)[0];
    seen_codes = (PyObject*)((void**)param)[1];
    if (PyCode_Check(o) && !PySet_Contains(all_codes, o)) {
        PyCodeObject *co = (PyCodeObject *)o;
        PyObject * id = PyLong_FromVoidPtr((void*)CODE_ADDR_TO_UID(co));
        if (PySet_Contains(seen_codes, id)) {
            // only emit if the code id has been seen!
            if (emit_code_object(co) < 0)
                return -1;
            if (PySet_Add(all_codes, o) < 0)
                return -1;
        }

        /* as a special case, recursively look for and add code
           objects found in the co_consts.  The problem is that code
           objects are not created as GC-aware in CPython, so we need
           to hack like this to hope to find most of them. 
        */
        i = PyTuple_Size(co->co_consts);
        while (i > 0) {
            --i;
            if (_look_for_code_object(PyTuple_GET_ITEM(co->co_consts, i),
                                      param) < 0)
                return -1;
        }
    }
    return 0;
}

static
void emit_all_code_objects(PyObject * seen_code_ids)
{
    PyObject *gc_module = NULL, *lst = NULL, *all_codes = NULL;
    Py_ssize_t i, size;
    void * param[2];

    gc_module = PyImport_ImportModuleNoBlock("gc");
    if (gc_module == NULL)
        goto error;

    // lst contains all objects that are known by the gc
    lst = PyObject_CallMethod(gc_module, "get_objects", "");
    if (lst == NULL || !PyList_Check(lst))
        goto error;

    // the set only includes the code objects found in the profile
    all_codes = PySet_New(NULL);
    if (all_codes == NULL)
        goto error;

    param[0] = all_codes;
    param[1] = seen_code_ids;

    size = PyList_GET_SIZE(lst);
    for (i = 0; i < size; i++) {
        PyObject *o = PyList_GET_ITEM(lst, i);
        if (o->ob_type->tp_traverse &&
            o->ob_type->tp_traverse(o, _look_for_code_object, (void*)param)
                < 0)
            goto error;
    }

 error:
    Py_XDECREF(all_codes);
    Py_XDECREF(lst);
    Py_XDECREF(gc_module);
}

static void cpyprof_code_dealloc(PyObject *co)
{
    if (vmprof_is_enabled()) {
        emit_code_object((PyCodeObject *)co);
        /* xxx error return values are ignored */
    }
    Original_code_dealloc(co);
}

static PyObject *enable_vmprof(PyObject* self, PyObject *args)
{
    int fd;
    int memory = 0;
    int lines = 0;
    int native = 0;
    int real_time = 0;
    double interval;
    char *p_error;

    if (!PyArg_ParseTuple(args, "id|iiii", &fd, &interval, &memory, &lines, &native, &real_time)) {
        return NULL;
    }

    if (write(fd, NULL, 0) != 0) {
        PyErr_SetString(PyExc_ValueError, "file descriptor must be writeable");
        return NULL;
    }

    if ((read(fd, NULL, 0) != 0) && (native != 0)) {
        PyErr_SetString(PyExc_ValueError, "file descriptor must be readable");
        return NULL;
    }

    if (vmprof_is_enabled()) {
        PyErr_SetString(PyExc_ValueError, "vmprof is already enabled");
        return NULL;
    }

#ifndef VMPROF_UNIX
    if (real_time) {
        PyErr_SetString(PyExc_ValueError, "real time profiling is only supported on Linux and MacOS");
        return NULL;
    }
#endif

    vmp_profile_lines(lines);

    if (!Original_code_dealloc) {
        Original_code_dealloc = PyCode_Type.tp_dealloc;
        PyCode_Type.tp_dealloc = &cpyprof_code_dealloc;
    }

    p_error = vmprof_init(fd, interval, memory, lines, "cpython", native, real_time);
    if (p_error) {
        PyErr_SetString(PyExc_ValueError, p_error);
        return NULL;
    }

    if (vmprof_enable(memory, native, real_time) < 0) {
        PyErr_SetFromErrno(PyExc_OSError);
        return NULL;
    }

    vmprof_set_enabled(1);

    Py_RETURN_NONE;
}

static PyObject * vmp_is_enabled(PyObject *module, PyObject *noargs) {
    if (vmprof_is_enabled()) {
        Py_RETURN_TRUE;
    }
    Py_RETURN_FALSE;
}

static PyObject *
disable_vmprof(PyObject *module, PyObject *noargs)
{
    if (vmprof_disable() < 0) {
        PyErr_SetFromErrno(PyExc_OSError);
        return NULL;
    }

    vmprof_set_enabled(0);

    if (PyErr_Occurred())
        return NULL;

    Py_RETURN_NONE;
}

static PyObject *
write_all_code_objects(PyObject *module, PyObject * seen_code_ids)
{
    // assumptions: signals must be disabled (see stop_sampling)
    emit_all_code_objects(seen_code_ids);

    if (PyErr_Occurred())
        return NULL;
    Py_RETURN_NONE;
}



static PyObject *
sample_stack_now(PyObject *module, PyObject * args)
{
    PyThreadState * tstate = NULL;
    PyObject * list = NULL;
    int i;
    int entry_count;
    void ** m;
    void * routine_ip;
    long skip = 0;

    // stop any signal to occur
    vmprof_ignore_signals(1);

    list = PyList_New(0);
    if (list == NULL) {
        goto error;
    }

    if (!PyArg_ParseTuple(args, "l", &skip)) {
        goto error;
    }

    tstate = PyGILState_GetThisThreadState();
    m = (void**)malloc(SINGLE_BUF_SIZE);
    if (m == NULL) {
        PyErr_SetString(PyExc_MemoryError, "could not allocate buffer for stack trace");
        vmprof_ignore_signals(0);
        return NULL;
    }
    entry_count = vmp_walk_and_record_stack(tstate->frame, m, SINGLE_BUF_SIZE/sizeof(void*)-1, (int)skip, 0);

    for (i = 0; i < entry_count; i++) {
        routine_ip = m[i];
        PyList_Append(list, PyLong_NEW((ssize_t)routine_ip));
    }

    free(m);

    vmprof_ignore_signals(0);
    Py_INCREF(list);
    return list;

error:
    vmprof_ignore_signals(0);
    Py_DECREF(list);
    Py_RETURN_NONE;
}

#ifdef VMP_SUPPORTS_NATIVE_PROFILING
static PyObject *
resolve_addr(PyObject *module, PyObject *args) {
    long long addr;
    PyObject * o_name = NULL;
    PyObject * o_lineno = NULL;
    PyObject * o_srcfile = NULL;
    char name[128];
    int lineno = 0;
    char srcfile[256];

    if (!PyArg_ParseTuple(args, "L", &addr)) {
        return NULL;
    }
    name[0] = '\x00';
    srcfile[0] = '-';
    srcfile[1] = '\x00';
    if (vmp_resolve_addr((void*)addr, name, 128, &lineno, srcfile, 256) != 0) {
        goto error;
    }

    o_name = PyStr_NEW(name);
    if (o_name == NULL) goto error;
    o_lineno = PyLong_NEW(lineno);
    if (o_lineno == NULL) goto error;
    o_srcfile = PyStr_NEW(srcfile);
    if (o_srcfile == NULL) goto error;
    //
    return PyTuple_Pack(3, o_name, o_lineno, o_srcfile);
error:
    Py_XDECREF(o_name);
    Py_XDECREF(o_lineno);
    Py_XDECREF(o_srcfile);

    Py_RETURN_NONE;
}
#endif

static PyObject *
stop_sampling(PyObject *module, PyObject *noargs)
{
    vmprof_ignore_signals(1);
    return PyLong_NEW(vmp_profile_fileno());
}

static PyObject *
start_sampling(PyObject *module, PyObject *noargs)
{
    vmprof_ignore_signals(0);
    Py_RETURN_NONE;
}

#ifdef VMPROF_UNIX
static PyObject * vmp_get_profile_path(PyObject *module, PyObject *noargs) {
    PyObject * o;
    if (vmprof_is_enabled()) {
        char buffer[4096];
        buffer[0] = 0;
        ssize_t buffer_len = vmp_fd_to_path(vmp_profile_fileno(), buffer, 4096);
        if (buffer_len == -1) {
            PyErr_Format(PyExc_NotImplementedError, "not implemented platform %s", vmp_machine_os_name());
            return NULL;
        }
        return PyStr_n_NEW(buffer, buffer_len);
    }
    Py_RETURN_NONE;
}
#endif


#ifdef VMPROF_UNIX
static PyObject *
insert_real_time_thread(PyObject *module, PyObject * args) {
    ssize_t thread_count;
    unsigned long thread_id = 0;
    pthread_t th = pthread_self();

    if (!PyArg_ParseTuple(args, "|k", &thread_id)) {
        return NULL;
    }

    if (thread_id) {
#if SIZEOF_LONG <= SIZEOF_PTHREAD_T
        th = (pthread_t) thread_id;
#else
        th = (pthread_t) *(unsigned long *) &thread_id;
#endif
    }

    if (!vmprof_is_enabled()) {
        PyErr_SetString(PyExc_ValueError, "vmprof is not enabled");
        return NULL;
    }

    if (vmprof_get_signal_type() != SIGALRM) {
        PyErr_SetString(PyExc_ValueError, "vmprof is not in real time mode");
        return NULL;
    }

    vmprof_aquire_lock();
    thread_count = insert_thread(th, -1);
    vmprof_release_lock();

    return PyLong_FromSsize_t(thread_count);
}

static PyObject *
remove_real_time_thread(PyObject *module, PyObject * args) {
    ssize_t thread_count;
    unsigned long thread_id = 0;
    pthread_t th = pthread_self();

    if (!PyArg_ParseTuple(args, "|k", &thread_id)) {
        return NULL;
    }

    if (thread_id) {
#if SIZEOF_LONG <= SIZEOF_PTHREAD_T
        th = (pthread_t) thread_id;
#else
        th = (pthread_t) *(unsigned long *) &thread_id;
#endif
    }

    if (!vmprof_is_enabled()) {
        PyErr_SetString(PyExc_ValueError, "vmprof is not enabled");
        return NULL;
    }

    if (vmprof_get_signal_type() != SIGALRM) {
        PyErr_SetString(PyExc_ValueError, "vmprof is not in real time mode");
        return NULL;
    }

    vmprof_aquire_lock();
    thread_count = remove_thread(th, -1);
    vmprof_release_lock();

    return PyLong_FromSsize_t(thread_count);
}
#endif

static PyMethodDef VMProfMethods[] = {
    {"enable",  enable_vmprof, METH_VARARGS, "Enable profiling."},
    {"disable", disable_vmprof, METH_NOARGS, "Disable profiling."},
    {"write_all_code_objects", write_all_code_objects, METH_O,
        "Write eagerly all the IDs of code objects"},
    {"sample_stack_now", sample_stack_now, METH_VARARGS,
        "Sample the stack now"},
    {"is_enabled", vmp_is_enabled, METH_NOARGS,
        "Indicates if vmprof is currently sampling."},
    {"stop_sampling", stop_sampling, METH_NOARGS,
        "Blocks signals to occur and returns the file descriptor"},
    {"start_sampling", start_sampling, METH_NOARGS,
        "Unblocks vmprof signals. After compeltion vmprof will sample again"},
#ifdef VMP_SUPPORTS_NATIVE_PROFILING
    {"resolve_addr", resolve_addr, METH_VARARGS,
        "Returns the name of the given address"},
#endif
#ifdef VMPROF_UNIX
    {"get_profile_path", vmp_get_profile_path, METH_NOARGS,
        "Profile path the profiler logs to."},
    {"insert_real_time_thread", insert_real_time_thread, METH_VARARGS,
        "Insert a thread into the real time profiling list."},
    {"remove_real_time_thread", remove_real_time_thread, METH_VARARGS,
        "Remove a thread from the real time profiling list."},
#endif
    {NULL, NULL, 0, NULL}        /* Sentinel */
};


#if PY_MAJOR_VERSION >= 3
static struct PyModuleDef VmprofModule = {
    PyModuleDef_HEAD_INIT,
    "_vmprof",
    "",  // doc
    -1,  // size
    VMProfMethods
};

PyMODINIT_FUNC PyInit__vmprof(void)
{
    return PyModule_Create(&VmprofModule);
}
#else
PyMODINIT_FUNC init_vmprof(void)
{
    Py_InitModule("_vmprof", VMProfMethods);
}
#endif
