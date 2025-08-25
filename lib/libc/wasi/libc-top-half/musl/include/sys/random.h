#ifndef _SYS_RANDOM_H
#define _SYS_RANDOM_H
#ifdef __cplusplus
extern "C" {
#endif

#ifdef __wasilibc_unmodified_upstream /* WASI has no getrandom, but it does have getentropy */
#define __NEED_size_t
#define __NEED_ssize_t
#include <bits/alltypes.h>

#define GRND_NONBLOCK	0x0001
#define GRND_RANDOM	0x0002
#define GRND_INSECURE	0x0004

ssize_t getrandom(void *, size_t, unsigned);
#else
#define __NEED_size_t
#include <bits/alltypes.h>

int getentropy(void *, size_t);
#endif

#ifdef __cplusplus
}
#endif
#endif
