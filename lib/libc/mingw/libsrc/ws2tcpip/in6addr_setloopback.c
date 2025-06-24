#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <ws2tcpip.h>

void IN6ADDR_SETLOOPBACK(struct sockaddr_in6 *a)
{
	a->sin6_family = AF_INET6;
	a->sin6_port = 0;
	a->sin6_flowinfo = 0;
	IN6_SET_ADDR_LOOPBACK(&a->sin6_addr);
	a->sin6_scope_id = 0;
}
