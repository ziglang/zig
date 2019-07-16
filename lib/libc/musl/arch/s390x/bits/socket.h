struct msghdr {
	void *msg_name;
	socklen_t msg_namelen;
	struct iovec *msg_iov;
	int __pad1, msg_iovlen;
	void *msg_control;
	int __pad2;
	socklen_t msg_controllen;
	int msg_flags;
};

struct cmsghdr {
	int __pad1;
	socklen_t cmsg_len;
	int cmsg_level;
	int cmsg_type;
};
