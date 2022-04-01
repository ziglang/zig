#include <Python.h>
#include "pythread.h"
#include "src/thread.h"
#include <windows.h>

/* ------------------------------------------------------------------------
Per-thread data ("key") support.

Use PyThread_create_key() to create a new key.  This is typically shared
across threads.

Use PyThread_set_key_value(thekey, value) to associate void* value with
thekey in the current thread.  Each thread has a distinct mapping of thekey
to a void* value.  Caution:  if the current thread already has a mapping
for thekey, value is ignored.

Use PyThread_get_key_value(thekey) to retrieve the void* value associated
with thekey in the current thread.  This returns NULL if no value is
associated with thekey in the current thread.

Use PyThread_delete_key_value(thekey) to forget the current thread's associated
value for thekey.  PyThread_delete_key(thekey) forgets the values associated
with thekey across *all* threads.

While some of these functions have error-return values, none set any
Python exception.

None of the functions does memory management on behalf of the void* values.
You need to allocate and deallocate them yourself.  If the void* values
happen to be PyObject*, these functions don't do refcount operations on
them either.

The GIL does not need to be held when calling these functions; they supply
their own locking.  This isn't true of PyThread_create_key(), though (see
next paragraph).

There's a hidden assumption that PyThread_create_key() will be called before
any of the other functions are called.  There's also a hidden assumption
that calls to PyThread_create_key() are serialized externally.
------------------------------------------------------------------------ */


/* use native Windows TLS functions */
#define Py_HAVE_NATIVE_TLS

int
PyThread_create_key(void)
{
    return (int) TlsAlloc();
}

void
PyThread_delete_key(int key)
{
    TlsFree(key);
}

/* We must be careful to emulate the strange semantics implemented in thread.c,
 * where the value is only set if it hasn't been set before.
 */
int
PyThread_set_key_value(int key, void *value)
{
    BOOL ok;
    void *oldvalue;

    assert(value != NULL);
    oldvalue = TlsGetValue(key);
    if (oldvalue != NULL)
        /* ignore value if already set */
        return 0;
    ok = TlsSetValue(key, value);
    if (!ok)
        return -1;
    return 0;
}

void *
PyThread_get_key_value(int key)
{
    /* because TLS is used in the Py_END_ALLOW_THREAD macro,
     * it is necessary to preserve the windows error state, because
     * it is assumed to be preserved across the call to the macro.
     * Ideally, the macro should be fixed, but it is simpler to
     * do it here.
     */
    DWORD error = GetLastError();
    void *result = TlsGetValue(key);
    SetLastError(error);
    return result;
}

void
PyThread_delete_key_value(int key)
{
    /* NULL is used as "key missing", and it is also the default
     * given by TlsGetValue() if nothing has been set yet.
     */
    TlsSetValue(key, NULL);
}

/* reinitialization of TLS is not necessary after fork when using
 * the native TLS functions.  And forking isn't supported on Windows either.
 */
void
PyThread_ReInitTLS(void)
{}

/*
   Platform-specific components of TSS API implementation.
*/

int
PyThread_tss_create(Py_tss_t *key)
{
    assert(key != NULL);
    /* If the key has been created, function is silently skipped. */
    if (key->_is_initialized) {
        return 0;
    }

    DWORD result = TlsAlloc();
    if (result == TLS_OUT_OF_INDEXES) {
        return -1;
    }
    /* In Windows, platform-specific key type is DWORD. */
    key->_key = result;
    key->_is_initialized = 1;
    return 0;
}

void
PyThread_tss_delete(Py_tss_t *key)
{
    assert(key != NULL);
    /* If the key has not been created, function is silently skipped. */
    if (!key->_is_initialized) {
        return;
    }

    TlsFree(key->_key);
    key->_key = TLS_OUT_OF_INDEXES;
    key->_is_initialized = 0;
}

int
PyThread_tss_set(Py_tss_t *key, void *value)
{
    assert(key != NULL);
    BOOL ok = TlsSetValue(key->_key, value);
    return ok ? 0 : -1;
}

void *
PyThread_tss_get(Py_tss_t *key)
{
    assert(key != NULL);
    /* because TSS is used in the Py_END_ALLOW_THREAD macro,
     * it is necessary to preserve the windows error state, because
     * it is assumed to be preserved across the call to the macro.
     * Ideally, the macro should be fixed, but it is simpler to
     * do it here.
     */
    DWORD error = GetLastError();
    void *result = TlsGetValue(key->_key);
    SetLastError(error);
    return result;
}

