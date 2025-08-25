#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#undef  __CRT__NO_INLINE
#define __CRT__NO_INLINE
#include <winsock2.h>
#include <ws2tcpip.h>

#undef  IN6_IS_ADDR_LOOPBACK
#define IN6_IS_ADDR_LOOPBACK(a)		( ((a)->s6_words[0] == 0) &&	\
					  ((a)->s6_words[1] == 0) &&	\
					  ((a)->s6_words[2] == 0) &&	\
					  ((a)->s6_words[3] == 0) &&	\
					  ((a)->s6_words[4] == 0) &&	\
					  ((a)->s6_words[5] == 0) &&	\
					  ((a)->s6_words[6] == 0) &&	\
					  ((a)->s6_words[7] == 0x0100) )

int IN6ADDR_ISLOOPBACK(const struct sockaddr_in6 *a)
{
	return ((a->sin6_family==AF_INET6) &&
		IN6_IS_ADDR_LOOPBACK(&a->sin6_addr));
}
