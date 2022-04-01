#include <Python.h>
#include "src/thread.h"

/* 
 * For platform-specific implementations, see 
 * pythread_nt.c and pythread_posix.c
 */

long
PyThread_get_thread_ident(void)
{
#ifdef _WIN32
    return (long)GetCurrentThreadId();
#else
    return (long)pthread_self();
#endif
}

static int initialized;

void
PyThread_init_thread(void)
{
    if (initialized)
        return;
    initialized = 1;
    /*PyThread__init_thread(); a NOP on modern platforms */
}

PyThread_type_lock
PyThread_allocate_lock(void)
{
    struct RPyOpaque_ThreadLock *lock;
    lock = malloc(sizeof(struct RPyOpaque_ThreadLock));
    if (lock == NULL)
        return NULL;

    if (RPyThreadLockInit(lock) == 0) {
        free(lock);
        return NULL;
    }

    return (PyThread_type_lock)lock;
}

void
PyThread_free_lock(PyThread_type_lock lock)
{
    struct RPyOpaque_ThreadLock *real_lock = lock;
    RPyThreadAcquireLock(real_lock, 0);
    RPyThreadReleaseLock(real_lock);
    RPyOpaqueDealloc_ThreadLock(real_lock);
    free(lock);
}

int
PyThread_acquire_lock(PyThread_type_lock lock, int waitflag)
{
    return RPyThreadAcquireLock((struct RPyOpaque_ThreadLock*)lock, waitflag);
}

void
PyThread_release_lock(PyThread_type_lock lock)
{
    RPyThreadReleaseLock((struct RPyOpaque_ThreadLock*)lock);
}

long
PyThread_start_new_thread(void (*func)(void *), void *arg)
{
    PyThread_init_thread();
    return RPyThreadStartEx(func, arg);
}

/* Cross-platform components of TSS API implementation.  */

Py_tss_t *
PyThread_tss_alloc(void)
{
    Py_tss_t *new_key = (Py_tss_t *)PyMem_RawMalloc(sizeof(Py_tss_t));
    if (new_key == NULL) {
        return NULL;
    }
    new_key->_is_initialized = 0;
    return new_key;
}

void
PyThread_tss_free(Py_tss_t *key)
{
    if (key != NULL) {
        PyThread_tss_delete(key);
        PyMem_RawFree((void *)key);
    }
}

int
PyThread_tss_is_created(Py_tss_t *key)
{
    assert(key != NULL);
    return key->_is_initialized;
}


