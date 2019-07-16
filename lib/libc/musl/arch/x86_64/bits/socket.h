struct msghdr {
	void *msg_name;
	socklen_t msg_namelen;
	struct iovec *msg_iov;
	int msg_iovlen, __pad1;
	void *msg_control;
	socklen_t msg_controllen, __pad2;
	int msg_flags;
};

struct cmsghdr {
	socklen_t cmsg_len;
	int __pad1;
	int cmsg_level;
	int cmsg_type;
};
