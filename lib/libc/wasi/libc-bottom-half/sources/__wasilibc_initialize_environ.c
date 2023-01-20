#include <unistd.h>
#include <stdlib.h>
#include <sysexits.h>
#include <wasi/api.h>
#include <wasi/libc.h>
#include <wasi/libc-environ.h>

/// If the program doesn't use `environ`, it'll get this version of
/// `__wasilibc_environ`, which isn't initialized with a constructor function.
/// `getenv` etc. call `__wasilibc_ensure_environ()` before accessing it.
/// Statically-initialize it to an invalid pointer value so that we can
/// detect if it's been explicitly initialized (we can't use `NULL` because
/// `clearenv` sets it to NULL.
weak char **__wasilibc_environ = (char **)-1;

// See the comments in libc-environ.h.
void __wasilibc_ensure_environ(void) {
    if (__wasilibc_environ == (char **)-1) {
        __wasilibc_initialize_environ();
    }
}

/// Avoid dynamic allocation for the case where there are no environment
/// variables, but we still need a non-NULL pointer to an (empty) array.
static char *empty_environ[1] = { NULL };

// See the comments in libc-environ.h.
void __wasilibc_initialize_environ(void) {
    // Get the sizes of the arrays we'll have to create to copy in the environment.
    size_t environ_count;
    size_t environ_buf_size;
    __wasi_errno_t err = __wasi_environ_sizes_get(&environ_count, &environ_buf_size);
    if (err != __WASI_ERRNO_SUCCESS) {
        goto oserr;
    }
    if (environ_count == 0) {
        __wasilibc_environ = empty_environ;
        return;
    }

    // Add 1 for the NULL pointer to mark the end, and check for overflow.
    size_t num_ptrs = environ_count + 1;
    if (num_ptrs == 0) {
        goto software;
    }

    // Allocate memory for storing the environment chars.
    char *environ_buf = malloc(environ_buf_size);
    if (environ_buf == NULL) {
        goto software;
    }

    // Allocate memory for the array of pointers. This uses `calloc` both to
    // handle overflow and to initialize the NULL pointer at the end.
    char **environ_ptrs = calloc(num_ptrs, sizeof(char *));
    if (environ_ptrs == NULL) {
        free(environ_buf);
        goto software;
    }

    // Fill the environment chars, and the `__wasilibc_environ` array with
    // pointers into those chars.
    // TODO: Remove the casts on `environ_ptrs` and `environ_buf` once the witx is updated with char8 support.
    err = __wasi_environ_get((uint8_t **)environ_ptrs, (uint8_t *)environ_buf);
    if (err != __WASI_ERRNO_SUCCESS) {
        free(environ_buf);
        free(environ_ptrs);
        goto oserr;
    }

    __wasilibc_environ = environ_ptrs;
    return;
oserr:
    _Exit(EX_OSERR);
software:
    _Exit(EX_SOFTWARE);
}

// See the comments in libc-environ.h.
void __wasilibc_deinitialize_environ(void) {
    if (__wasilibc_environ != (char **)-1) {
        // Let libc-top-half clear the old environment-variable strings.
        clearenv();
        // Set the pointer to the special init value.
        __wasilibc_environ = (char **)-1;
    }
}

// See the comments in libc-environ.h.
weak void __wasilibc_maybe_reinitialize_environ_eagerly(void) {
    // This version does nothing. It may be overridden by a version which does
    // something if `environ` is used.
}
