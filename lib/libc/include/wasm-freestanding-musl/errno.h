#ifndef	_ERRNO_H
#define _ERRNO_H

#ifdef __cplusplus
extern "C" {
#endif

#ifdef WASM_THREAD_MODEL_SINGLE
extern int errno;
#else
#ifdef __cplusplus
extern thread_local int errno;
#else
extern _Thread_local int errno;
#endif
#endif

#define errno errno

#ifdef __cplusplus
}
#endif

#endif
