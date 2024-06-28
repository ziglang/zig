// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <common/time.h>

#include <sys/select.h>

#include <wasi/api.h>
#include <errno.h>
#include <poll.h>

int pselect(int nfds, fd_set *restrict readfds, fd_set *restrict writefds,
            fd_set *restrict errorfds, const struct timespec *restrict timeout,
            const sigset_t *sigmask) {
  // Negative file descriptor upperbound.
  if (nfds < 0) {
    errno = EINVAL;
    return -1;
  }

  // This implementation does not support polling for exceptional
  // conditions, such as out-of-band data on TCP sockets.
  if (errorfds != NULL && errorfds->__nfds > 0) {
    errno = ENOSYS;
    return -1;
  }

  // Replace NULL pointers by the empty set.
  fd_set empty;
  FD_ZERO(&empty);
  if (readfds == NULL)
    readfds = &empty;
  if (writefds == NULL)
    writefds = &empty;

  struct pollfd poll_fds[readfds->__nfds + writefds->__nfds];
  size_t poll_nfds = 0;
  
  for (size_t i = 0; i < readfds->__nfds; ++i) {
    int fd = readfds->__fds[i];
    if (fd < nfds) {
        poll_fds[poll_nfds++] = (struct pollfd){
            .fd = fd,
            .events = POLLRDNORM,
            .revents = 0
        };
    }
  }
  
  for (size_t i = 0; i < writefds->__nfds; ++i) {
    int fd = writefds->__fds[i];
    if (fd < nfds) {
      poll_fds[poll_nfds++] = (struct pollfd){
          .fd = fd,
          .events = POLLWRNORM,
          .revents = 0
      };
    }
  }

  int poll_timeout;
  if (timeout) {
    uint64_t timeout_u64;
    if (!timespec_to_timestamp_clamp(timeout, &timeout_u64) ) {
      errno = EINVAL;
      return -1;
    }

    // Convert nanoseconds to milliseconds:
    timeout_u64 /= 1000000;

    if (timeout_u64 > INT_MAX) {
      timeout_u64 = INT_MAX;
    }

    poll_timeout = (int) timeout_u64;
  } else {
    poll_timeout = -1;
  };
  
  if (poll(poll_fds, poll_nfds, poll_timeout) < 0) {
    return -1;
  }

  FD_ZERO(readfds);
  FD_ZERO(writefds);
  for (size_t i = 0; i < poll_nfds; ++i) {
    struct pollfd* pollfd = poll_fds + i;
    if ((pollfd->revents & POLLRDNORM) != 0) {
      readfds->__fds[readfds->__nfds++] = pollfd->fd;
    }
    if ((pollfd->revents & POLLWRNORM) != 0) {
      writefds->__fds[writefds->__nfds++] = pollfd->fd;
    }
  }
  
  return readfds->__nfds + writefds->__nfds;
}
