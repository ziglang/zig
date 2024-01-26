#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <ws2tcpip.h>

#undef  IN6_IS_ADDR_MULTICAST
#define IN6_IS_ADDR_MULTICAST(a)	( (a)->s6_bytes[0] == 0xff )

int IN6_IS_ADDR_MC_NODELOCAL(const struct in6_addr *a)
{
	return IN6_IS_ADDR_MULTICAST(a) &&
		((a->s6_bytes[1] & 0xf) == 1);
}
