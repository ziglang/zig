#ifndef __wasi_libc_environ_h
#define __wasi_libc_environ_h

/// This header file is a WASI-libc-specific interface, and is not needed by
/// most programs. Most programs should just use the standard `getenv` and
/// related APIs, which take care of all of the details automatically.

#ifdef __cplusplus
extern "C" {
#endif

/// Initialize the global environment variable state. Only needs to be
/// called once; most users should call `__wasilibc_ensure_environ` instead.
void __wasilibc_initialize_environ(void);

/// If `__wasilibc_initialize_environ` has not yet been called, call it.
void __wasilibc_ensure_environ(void);

/// De-initialize the global environment variable state, so that subsequent
/// calls to `__wasilibc_ensure_environ` call `__wasilibc_initialize_environ`.
void __wasilibc_deinitialize_environ(void);

/// Call `__wasilibc_initialize_environ` only if `environ` and `_environ` are
/// referenced in the program.
void __wasilibc_maybe_reinitialize_environ_eagerly(void);

/// Return the value of the `environ` variable. Using `environ` directly
/// requires eager initialization of the environment variables. Using this
/// function instead of `environ` allows initialization to happen lazily.
char **__wasilibc_get_environ(void);

#ifdef __cplusplus
}
#endif

#endif
