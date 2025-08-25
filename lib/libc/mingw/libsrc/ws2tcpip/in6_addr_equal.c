#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <ws2tcpip.h>

int IN6_ADDR_EQUAL(const struct in6_addr *a,const struct in6_addr *b)
{
	return (memcmp(a, b, sizeof(struct in6_addr)) == 0);
}
