#ifndef __wasilibc___fd_set_h
#define __wasilibc___fd_set_h

#include <__typedef_fd_set.h>

#ifdef __cplusplus
extern "C" {
#endif

void FD_CLR(int, fd_set *);
int FD_ISSET(int, const fd_set *);
void FD_SET(int, fd_set *);
void FD_ZERO(fd_set *);
void FD_COPY(const fd_set *, fd_set *);

#define FD_CLR(fd, set) FD_CLR((fd), (set))
#define FD_ISSET(fd, set) FD_ISSET((fd), (set))
#define FD_SET(fd, set) FD_SET((fd), (set))
#define FD_ZERO(set) FD_ZERO((set))
#define FD_COPY(from, to) FD_COPY(from, to)

#ifdef __cplusplus
}
#endif

#endif
