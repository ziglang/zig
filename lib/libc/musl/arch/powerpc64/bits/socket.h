#include <endian.h>

struct msghdr {
	void *msg_name;
	socklen_t msg_namelen;
	struct iovec *msg_iov;
#if __BYTE_ORDER == __BIG_ENDIAN
	int __pad1, msg_iovlen;
#else
	int msg_iovlen, __pad1;
#endif
	void *msg_control;
#if __BYTE_ORDER == __BIG_ENDIAN
	int __pad2;
	socklen_t msg_controllen;
#else
	socklen_t msg_controllen;
	int __pad2;
#endif
	int msg_flags;
};

struct cmsghdr {
#if __BYTE_ORDER == __BIG_ENDIAN
	int __pad1;
	socklen_t cmsg_len;
#else
	socklen_t cmsg_len;
	int __pad1;
#endif
	int cmsg_level;
	int cmsg_type;
};

#define SO_DEBUG        1
#define SO_REUSEADDR    2
#define SO_TYPE         3
#define SO_ERROR        4
#define SO_DONTROUTE    5
#define SO_BROADCAST    6
#define SO_SNDBUF       7
#define SO_RCVBUF       8
#define SO_KEEPALIVE    9
#define SO_OOBINLINE    10
#define SO_NO_CHECK     11
#define SO_PRIORITY     12
#define SO_LINGER       13
#define SO_BSDCOMPAT    14
#define SO_REUSEPORT    15
#define SO_RCVLOWAT     16
#define SO_SNDLOWAT     17
#define SO_RCVTIMEO     18
#define SO_SNDTIMEO     19
#define SO_PASSCRED     20
#define SO_PEERCRED     21
#define SO_ACCEPTCONN   30
#define SO_PEERSEC      31
#define SO_SNDBUFFORCE  32
#define SO_RCVBUFFORCE  33
#define SO_PROTOCOL     38
#define SO_DOMAIN       39
