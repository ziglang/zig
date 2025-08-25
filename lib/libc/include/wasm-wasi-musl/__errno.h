#ifndef __wasilibc___errno_h
#define __wasilibc___errno_h

#ifdef __cplusplus
extern "C" {
#endif

extern _Thread_local int errno;

#define errno errno

#ifdef __cplusplus
}
#endif
#endif
