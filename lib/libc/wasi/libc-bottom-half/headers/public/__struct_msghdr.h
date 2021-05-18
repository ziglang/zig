#ifndef __wasilibc___struct_msghdr_h
#define __wasilibc___struct_msghdr_h

#include <__typedef_socklen_t.h>

struct msghdr {
    void *msg_name;
    socklen_t msg_namelen;
    struct iovec *msg_iov;
    int msg_iovlen;
    void *msg_control;
    socklen_t msg_controllen;
    int msg_flags;
};

#endif
