#ifndef __wasi_libc_busywait_h
#define __wasi_libc_busywait_h

#ifdef __cplusplus
extern "C" {
#endif

/// Enable busywait in futex on current thread.
void __wasilibc_enable_futex_busywait_on_current_thread(void);

#ifdef __cplusplus
}
#endif

#endif 
