#ifndef __wasm_basics___errno_h
#define __wasm_basics___errno_h

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __cplusplus
extern thread_local int errno;
#else
extern _Thread_local int errno;
#endif

#define errno errno

#ifdef __cplusplus
}
#endif

#endif
