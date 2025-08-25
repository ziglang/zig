#ifndef	_SYS_UN_H
#define	_SYS_UN_H

#ifdef __cplusplus
extern "C" {
#endif

#include <features.h>

#define __NEED_sa_family_t
#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
#define __NEED_size_t
#endif

#include <bits/alltypes.h>

#ifdef __wasilibc_unmodified_upstream /* WASI has no UNIX-domain sockets */
struct sockaddr_un {
	sa_family_t sun_family;
	char sun_path[108];
};
#else
#include <__struct_sockaddr_un.h>
#endif

#if defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
#ifdef __wasilibc_unmodified_upstream /* Declare strlen with the same attributes as <string.h> uses */
size_t strlen(const char *);
#else
size_t strlen(const char *) __attribute__((__nothrow__, __leaf__, __pure__, __nonnull__(1)));
#endif
#define SUN_LEN(s) (2+strlen((s)->sun_path))
#endif

#ifdef __cplusplus
}
#endif

#endif
