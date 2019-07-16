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
