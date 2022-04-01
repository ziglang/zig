#ifndef Py_PYTHREAD_H
#define Py_PYTHREAD_H

#define WITH_THREAD

typedef void *PyThread_type_lock;

#ifdef __cplusplus
extern "C" {
#endif

PyAPI_FUNC(long) PyThread_get_thread_ident(void);

PyAPI_FUNC(PyThread_type_lock) PyThread_allocate_lock(void);
PyAPI_FUNC(void) PyThread_free_lock(PyThread_type_lock);
PyAPI_FUNC(int) PyThread_acquire_lock(PyThread_type_lock, int);
#define WAIT_LOCK	1
#define NOWAIT_LOCK	0
PyAPI_FUNC(void) PyThread_release_lock(PyThread_type_lock);

PyAPI_FUNC(void) PyThread_init_thread(void);
PyAPI_FUNC(long) PyThread_start_new_thread(void (*func)(void *), void *arg);

/* Thread Local Storage (TLS) API */
PyAPI_FUNC(int) PyThread_create_key(void);
PyAPI_FUNC(void) PyThread_delete_key(int);
PyAPI_FUNC(int) PyThread_set_key_value(int, void *);
PyAPI_FUNC(void *) PyThread_get_key_value(int);
PyAPI_FUNC(void) PyThread_delete_key_value(int key);

/* Cleanup after a fork */
PyAPI_FUNC(void) PyThread_ReInitTLS(void);

#if !defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x03070000
/* New in 3.7 */
/* Thread Specific Storage (TSS) API */

typedef struct _Py_tss_t Py_tss_t;  /* opaque */

#ifndef Py_LIMITED_API
#if defined(_POSIX_THREADS)
    /* Darwin needs pthread.h to know type name the pthread_key_t. */
#   include <pthread.h>
#   define NATIVE_TSS_KEY_T     pthread_key_t
#elif defined(_WIN32)
    /* In Windows, native TSS key type is DWORD,
       but hardcode the unsigned long to avoid errors for include directive.
    */
#   define NATIVE_TSS_KEY_T     unsigned long
#else
#   error "Require native threads. See https://bugs.python.org/issue31370"
#endif

/* When Py_LIMITED_API is not defined, the type layout of Py_tss_t is
   exposed to allow static allocation in the API clients.  Even in this case,
   you must handle TSS keys through API functions due to compatibility.
*/
struct _Py_tss_t {
    int _is_initialized;
    NATIVE_TSS_KEY_T _key;
};

#undef NATIVE_TSS_KEY_T

/* When static allocation, you must initialize with Py_tss_NEEDS_INIT. */
#define Py_tss_NEEDS_INIT   {0}
#endif  /* !Py_LIMITED_API */

PyAPI_FUNC(Py_tss_t *) PyThread_tss_alloc(void);
PyAPI_FUNC(void) PyThread_tss_free(Py_tss_t *key);

/* The parameter key must not be NULL. */
PyAPI_FUNC(int) PyThread_tss_is_created(Py_tss_t *key);
PyAPI_FUNC(int) PyThread_tss_create(Py_tss_t *key);
PyAPI_FUNC(void) PyThread_tss_delete(Py_tss_t *key);
PyAPI_FUNC(int) PyThread_tss_set(Py_tss_t *key, void *value);
PyAPI_FUNC(void *) PyThread_tss_get(Py_tss_t *key);
#endif  /* New in 3.7 */

#ifdef __cplusplus
}
#endif

#endif
