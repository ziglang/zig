#ifndef __wasilibc___header_poll_h
#define __wasilibc___header_poll_h

#include <__struct_pollfd.h>
#include <__typedef_nfds_t.h>

#define POLLRDNORM 0x1
#define POLLWRNORM 0x2

#define POLLIN POLLRDNORM
#define POLLOUT POLLWRNORM

#define POLLERR 0x1000
#define POLLHUP 0x2000
#define POLLNVAL 0x4000

#ifdef __cplusplus
extern "C" {
#endif

int poll(struct pollfd[], nfds_t, int);

#ifdef __cplusplus
}
#endif

#endif
