#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <ws2tcpip.h>

void IN6_SET_ADDR_UNSPECIFIED(struct in6_addr *a)
{
	memset(a->s6_bytes, 0, sizeof(struct in6_addr));
}
