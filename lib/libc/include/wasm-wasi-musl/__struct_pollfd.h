#ifndef __wasilibc___struct_pollfd_h
#define __wasilibc___struct_pollfd_h

struct pollfd {
    int fd;
    short events;
    short revents;
};

#endif
