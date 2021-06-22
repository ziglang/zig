#ifndef __wasi_libc_environ_h
#define __wasi_libc_environ_h

#ifdef __cplusplus
extern "C" {
#endif

/// Initialize the global environment variable state. Only needs to be
/// called once; most users should call `__wasilibc_ensure_environ` instead.
void __wasilibc_initialize_environ(void);

/// If `__wasilibc_initialize_environ` has not yet been called, call it.
void __wasilibc_ensure_environ(void);

#ifdef __cplusplus
}
#endif

#endif
