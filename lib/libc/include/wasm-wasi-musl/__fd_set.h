#ifndef __wasilibc___fd_set_h
#define __wasilibc___fd_set_h

#include <__typedef_fd_set.h>

#ifdef __cplusplus
extern "C" {
#endif

static __inline void FD_CLR(int __fd, fd_set *__set) {
    size_t __n = __set->__nfds;
    for (int *__p = __set->__fds, *__e = __p + __n;
         __p < __e; ++__p)
    {
        if (*__p == __fd) {
            *__p = __e[-1];
            __set->__nfds = __n - 1;
            return;
        }
    }
}

static __inline
#ifdef __cplusplus
bool
#else
_Bool
#endif
FD_ISSET(int __fd, const fd_set *__set)
{
    size_t __n = __set->__nfds;
    for (const int *__p = __set->__fds, *__e = __p + __n;
         __p < __e; ++__p)
    {
        if (*__p == __fd) {
            return 1;
        }
    }
    return 0;
}

static __inline void FD_SET(int __fd, fd_set *__set) {
    size_t __n = __set->__nfds;
    for (const int *__p = __set->__fds, *__e = __p + __n;
         __p < __e; ++__p)
    {
        if (*__p == __fd) {
            return;
        }
    }
    __set->__nfds = __n + 1;
    __set->__fds[__n] = __fd;
}

static __inline void FD_ZERO(fd_set *__set) {
    __set->__nfds = 0;
}

static __inline void FD_COPY(const fd_set *__restrict __from,
                             fd_set *__restrict __to) {
    size_t __n = __from->__nfds;
    __to->__nfds = __n;
    __builtin_memcpy(__to->__fds, __from->__fds, __n * sizeof(int));
}

#define FD_CLR(fd, set)   (FD_CLR((fd), (set)))
#define FD_ISSET(fd, set) (FD_ISSET((fd), (set)))
#define FD_SET(fd, set)   (FD_SET((fd), (set)))
#define FD_ZERO(set)      (FD_ZERO((set)))
#define FD_COPY(from, to) (FD_COPY((from), (to)))

#ifdef __cplusplus
}
#endif

#endif
